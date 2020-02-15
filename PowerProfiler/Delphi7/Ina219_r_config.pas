unit Ina219_r_config;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Spin;

const
  ConfigResetMsk = $8000;

  BusVoltageRangeMsk = $2000;
  BusVoltageRangeShl = 13;

  ControlGainMsk = $1800;
  ControlGainShl = 11;

  BusADCResolutionShl = 7;
  BusADCResolutionMsk = $0780;
  BusADCResolutionCnt = 12;

  ShuntADCResolutionShl = 3;
  ShuntADCResolutionMsk = $0078;
  ShuntADCResolutionCnt = 12;

  ConfigModeMsk = 7;

  SMBus_219_Speed_Max_kHz = 2500;
  SMBus_219_Speed_kHz = 1000; // default
  SMBus_219_Speed_Min_kHz = 100;

type
  TForm219Config = class(TForm)
    RadioGroupBusRange: TRadioGroup;
    RadioGroupGain: TRadioGroup;
    RadioGroupShuntADCRes: TRadioGroup;
    RadioGroupMode: TRadioGroup;
    ButtonOk: TButton;
    ButtonCancel: TButton;
    RadioGroupBusADCRes: TRadioGroup;
    GroupBox1: TGroupBox;
    CheckBoxReset: TCheckBox;
    LabelRegConfig: TLabel;
    SpinEditCLkKHz: TSpinEdit;
    Label1: TLabel;
    Label2: TLabel;
    procedure FormActivate(Sender: TObject);
    procedure ButtonOkClick(Sender: TObject);
    procedure ChargeReg(Sender: TObject);
    procedure GetParamIz;
    procedure GetParams;
    procedure SetParamIU(i : double ; u : double);
    function DevIniCfg(mode : integer) : byte;
  private
    { Private declarations }
    ChgEna : boolean;
    procedure CheckRegValue;
  public
    { Public declarations }
    reg_config : word;
  end;

var
  Form219Config: TForm219Config;

  TabBusADCResolution : array [0..ShuntADCResolutionCnt-1] of word =
   ($0000, $0080, $0100, $0180,
    $0400, $0480, $0500, $0580,
    $0600, $0680, $0700, $0780 );

  TabShuntADCResolution : array [0..ShuntADCResolutionCnt-1] of word =
   ($0000, $0008, $0010, $0018,
    $0040, $0048, $0050, $0058,
    $0060, $0068, $0070, $0078 );

  TabTimerResolution : array [0..ShuntADCResolutionCnt-1] of dword =
   (86, 148, 276, 532,
    532, 1006, 2130, 4260,
    8510, 17020, 34050, 68100);

  TabBusClkResolution : array [0..ShuntADCResolutionCnt-1] of word =
   (1000, 800, 800, 800,
    800, 800, 800, 800,
    800, 800, 800, 800);

  Uk_219 : double = 0.0005024; // 0.0005004
  Ik_219 : double = 0.09475; // 0.09475
  I_219_zero : double = 0.0;
  U_219_zero : double = 0.0;


  I_219_zero_tab : array [0..3] of double = (
   0.095, // 0.095  mA x 40 mV
   0.19, // 0.19   mA x 80 mV
   0.155, // 0.155 mA x 160 mV
   0.284 // 0.284 mA x 320 mV
  );


implementation

{$R *.dfm}
Uses MainFrm;

procedure TForm219Config.FormActivate(Sender: TObject);
var
 i : integer;
 mask : word;
begin
     ChgEna := False;
     reg_config := ina2xx_reg.config;
     if (reg_config and ConfigResetMsk) <> 0 then
        CheckBoxReset.Checked := True
     else
       CheckBoxReset.Checked := False;

     RadioGroupBusRange.ItemIndex := (reg_config and BusVoltageRangeMsk) shr BusVoltageRangeShl;

     RadioGroupGain.ItemIndex := (reg_config and ControlGainMsk) shr ControlGainShl;


     mask := reg_config and BusADCResolutionMsk;
     for i:=0 to BusADCResolutionCnt do begin
       if mask = TabBusADCResolution[i] then break;
     end;
     RadioGroupBusADCRes.ItemIndex := i;

     mask := reg_config and ShuntADCResolutionMsk;
     for i:=0 to ShuntADCResolutionCnt do begin
       if mask = TabShuntADCResolution[i] then break;
     end;
     RadioGroupShuntADCRes.ItemIndex := i;

     RadioGroupMode.ItemIndex := reg_config and ConfigModeMsk;
     LabelRegConfig.Caption := 'RegControl = 0x' + IntToHex(reg_config, 4);
     ChgEna := True;
end;

procedure TForm219Config.CheckRegValue;
begin
     reg_config := (RadioGroupBusRange.ItemIndex shl BusVoltageRangeShl) and BusVoltageRangeMsk;
     reg_config := reg_config or ((RadioGroupGain.ItemIndex shl ControlGainShl) and ControlGainMsk);
     reg_config := reg_config or TabBusADCResolution[RadioGroupBusADCRes.ItemIndex and 15];
     reg_config := reg_config or TabShuntADCResolution[RadioGroupShuntADCRes.ItemIndex and 15];
     reg_config := reg_config or (RadioGroupMode.ItemIndex and ConfigModeMsk);
     if CheckBoxReset.Checked then reg_config := reg_config or ConfigResetMsk;
     LabelRegConfig.Caption := 'RegControl = 0x' + IntToHex(reg_config,4);
end;

procedure TForm219Config.ButtonOkClick(Sender: TObject);
var
 clk_khz : integer;
begin
     CheckRegValue;
     if RadioGroupBusADCRes.ItemIndex < RadioGroupShuntADCRes.ItemIndex then
         clk_khz := TabBusClkResolution[RadioGroupShuntADCRes.ItemIndex]
     else
         clk_khz := TabBusClkResolution[RadioGroupBusADCRes.ItemIndex];
     if SpinEditCLkKHz.Value < clk_khz then begin
        ShowMessage('BUS CLK Low!' + #13#10 +'Min CLK ' + IntToStr(clk_khz) + ' kHz!');
        SpinEditCLkKHz.Value := clk_khz;
        ModalResult := mrNone;
        Exit;
     end;

     I_219_zero := I_219_zero_tab[RadioGroupGain.ItemIndex];
     ina2xx_reg.config := reg_config;

     ModalResult := mrOk;
     Exit;
end;

procedure TForm219Config.ChargeReg(Sender: TObject);
begin
  if ChgEna then CheckRegValue;
end;

procedure TForm219Config.GetParamIz;
begin
  I_zero := I_219_zero;
  U_zero := U_219_zero;
end;

procedure TForm219Config.GetParams;
begin
  I_zero := I_219_zero;
  U_zero := U_219_zero;
  Ik := Ik_219;
  Uk := Uk_219;
end;

procedure TForm219Config.SetParamIU(i : double ; u : double);
begin
  Ik_219 := i;
  Uk_219 := u;
end;

function TForm219Config.DevIniCfg(mode : integer) : byte;
var
  mask : word;
  u, i : word;
  t, x : dword;
begin
     mask := ina2xx_reg.config and BusADCResolutionMsk;
     for u:=0 to BusADCResolutionCnt do begin
       if mask = TabBusADCResolution[u] then break;
     end;

     mask := ina2xx_reg.config and ShuntADCResolutionMsk;
     for i:=0 to ShuntADCResolutionCnt do begin
       if mask = TabShuntADCResolution[i] then break;
     end;

     // ���������������� � INA219 ��������:
     // �������� 1 �������:
     blk_cfg.init[0].dev_addr := INA2XX_I2C_ADDR;
     blk_cfg.init[0].reg_addr := 0;
     blk_cfg.init[0].data := ina2xx_reg.config;
     // �������� ������ �������� ?:
     blk_cfg.init[1].dev_addr := 0;
//   blk_cfg.init[1].reg_addr := 5;
//   blk_cfg.init[1].data := ina2xx_reg.calibration;

     mask := ina2xx_reg.config and ConfigModeMsk;
     // ������ ������ ��������� ������
     case mask of
         5 : begin // Shunt
             result := CHART_I_MASK;
             blk_cfg.data[0].dev_addr := INA2XX_I2C_ADDR;
             blk_cfg.data[0].reg_addr := 1;
             blk_cfg.data[1].dev_addr := 0; // stop rd
             t := TabTimerResolution[i];
            end;
         6 : begin // Bus
             result := CHART_U_MASK;
             blk_cfg.data[0].dev_addr := INA2XX_I2C_ADDR;
             blk_cfg.data[0].reg_addr := 2;
             blk_cfg.data[1].dev_addr := 0; // stop rd
             t := TabTimerResolution[u];
            end;
         7 : begin // Shunt + Bus
             result := CHART_UI_MASK;
             blk_cfg.data[0].dev_addr := INA2XX_I2C_ADDR;
             blk_cfg.data[0].reg_addr := 1;
             blk_cfg.data[1].dev_addr := INA2XX_I2C_ADDR;
             blk_cfg.data[1].reg_addr := 2;
             blk_cfg.data[2].dev_addr := 0; // stop rd
             t := (TabTimerResolution[i] + TabTimerResolution[u]) div 2;
            end;
         else begin
            result := 0;
            blk_cfg.data[0].dev_addr := 0;
            t := 10000;
            end;
      end;
     if(mode <> 0) then begin
       if dev_id = ADC_DEVICE_ID then begin
         // ������ �������� ��������� � ������
         x := t div (30000 div MAX_BLK_DEV2);
         if(x > (MAX_BLK_DEV2-1)) then x := (MAX_BLK_DEV2-12);
         if mask = 7 then x := x and $fffe;
         blk_cfg.pktcnt := MAX_BLK_DEV2 - x;
       end else begin
         // ������ �������� ��������� � ������
         x := t div (30000 div 30);
         if(x > (MAX_BLK_DEV1-1)) then x := (MAX_BLK_DEV1-1);
         if mask = 7 then x := x and $fffe;
         blk_cfg.pktcnt := MAX_BLK_DEV1 - x;
       end;
     end else
       blk_cfg.pktcnt := 0;  // stop
     // ������ ����� ������ ���������
     x := 0;
     while t > $ffff do begin
        t := t shr 1;
        x := x + 1;
     end;
     blk_cfg.time_us := t;
     blk_cfg.multiplier := x;
     // ������ �������� ��������� � ������
     blk_cfg.clk_khz := SpinEditCLkKHz.Value;
end;


end.
