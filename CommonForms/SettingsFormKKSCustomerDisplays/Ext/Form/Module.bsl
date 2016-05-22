
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("ID", ID);
	Parameters.Property("HardwareDriver", HardwareDriver);
	
	Title = NStr("en='Equipment:'") + Chars.NBSp  + String(ID);

	TextColor = StyleColors.FormTextColor;
	ErrorColor = StyleColors.NegativeTextColor;

	ListPort = Items.Port.ChoiceList;
	For Number = 1 To 64 Do
		ListPort.Add(Number, "COM" + Format(Number, "ND=2; NFD=0; NZ=0; NG=0"));
	EndDo;
	
	ListModel = Items.Model.ChoiceList;
	ListModel.Add("Spark-PD-2001");

	SpeedList = Items.Speed.ChoiceList;
	SpeedList.Add(9600,   "9600");
    SpeedList.Add(19200,  "19200");
	SpeedList.Add(57600,  "57600");
	SpeedList.Add(115200, "115200");
	
	ParityList = Items.Parity.ChoiceList;
	ParityList.Add(0, NStr("en='No'"));
	ParityList.Add(1, NStr("en='Oddness'"));
	ParityList.Add(2, NStr("en='Parity'"));
	ParityList.Add(3, NStr("en='Installed'"));
	ParityList.Add(4, NStr("en='Reset'"));

	DataBitsList = Items.DataBits.ChoiceList;
	DataBitsList.Add(7, "7 bits");
	DataBitsList.Add(8, "8 bits");

	BitStopList = Items.StopBits.ChoiceList;
	BitStopList.Add(1, "1 bit");
	BitStopList.Add(2, "2 bits");
	
	tempModel     = Undefined;
	tempPort       = Undefined;
	tempSpeed   = Undefined;
	tempParity   = Undefined;
	tempDataBits = Undefined;
	tempStopBits   = Undefined;
	
	Parameters.EquipmentParameters.Property("Model",          tempModel);
	Parameters.EquipmentParameters.Property("Port",            tempPort);
	Parameters.EquipmentParameters.Property("Speed",        tempSpeed);
	Parameters.EquipmentParameters.Property("Parity",        tempParity);
	Parameters.EquipmentParameters.Property("DataBits",      tempDataBits);
	Parameters.EquipmentParameters.Property("StopBits",        tempStopBits);
	
	Model          = ?(tempModel          = Undefined, "Spark-PD-2001", tempModel);
	Port            = ?(tempPort            = Undefined,               1, tempPort);
	Speed        = ?(tempSpeed        = Undefined,            9600, tempSpeed);
	Parity        = ?(tempParity        = Undefined,               0, tempParity);
	DataBits      = ?(tempDataBits      = Undefined,               7, tempDataBits);
	StopBits        = ?(tempStopBits        = Undefined,               1, tempStopBits);
	
	Items.DeviceTest.Visible    = (SessionParameters.ClientWorkplace = ID.Workplace);
	Items.SetupDriver.Visible = (SessionParameters.ClientWorkplace = ID.Workplace);

EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	UpdateInformationAboutDriver();
	SetEnabledOfItems();

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()
	
	ParametersNewValue = New Structure;
	ParametersNewValue.Insert("Model"     , Model);
	ParametersNewValue.Insert("Port"       , Port);
	ParametersNewValue.Insert("Speed"   , Speed);
	ParametersNewValue.Insert("Parity"   , Parity);
	ParametersNewValue.Insert("DataBits" , DataBits);
	ParametersNewValue.Insert("StopBits"   , StopBits);
	
	Result = New Structure;
	Result.Insert("ID", ID);
	Result.Insert("EquipmentParameters", ParametersNewValue);
	
	Close(Result);
	
EndProcedure

&AtClient
Procedure SetDriverFromArchiveOnEnd(Result) Export 
	
	CommonUseClientServer.MessageToUser(NStr("en='Driver is installed.'")); 
	UpdateInformationAboutDriver();
	
EndProcedure 

&AtClient
Procedure SettingDriverFromDistributionOnEnd(Result, Parameters) Export 
	
	If Result Then
		CommonUseClientServer.MessageToUser(NStr("en='Driver is installed.'")); 
		UpdateInformationAboutDriver();
	Else
		CommonUseClientServer.MessageToUser(NStr("en='An error occurred when installing the driver from distribution.'")); 
	EndIf;

EndProcedure 

&AtClient
Procedure SetupDriver(Command)

	ClearMessages();
	NotificationsDriverFromDistributionOnEnd = New NotifyDescription("SettingDriverFromDistributionOnEnd", ThisObject);
	NotificationsDriverFromArchiveOnEnd = New NotifyDescription("SetDriverFromArchiveOnEnd", ThisObject);
	EquipmentManagerClient.SetupDriver(HardwareDriver, NotificationsDriverFromDistributionOnEnd, NotificationsDriverFromArchiveOnEnd);
	
EndProcedure

&AtClient
Procedure DeviceTest(Command)
	
	ClearMessages();
	
	TestResult = Undefined;

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port", Port);
	tempDeviceParameters.Insert("Speed", Speed);
	tempDeviceParameters.Insert("Parity", Parity);
	tempDeviceParameters.Insert("DataBits", DataBits);
	tempDeviceParameters.Insert("StopBits", StopBits);
	
	Result = EquipmentManagerClient.RunAdditionalCommand("CheckHealth",
	                                                                      InputParameters,
	                                                                      Output_Parameters,
	                                                                      ID,
	                                                                      tempDeviceParameters);
	AdditionalDetails = ?(TypeOf(Output_Parameters) = Type("Array")
	                           AND Output_Parameters.Count() >= 2,
	                           NStr("en = 'Additional description:'") + " " + Output_Parameters[1],
	                           "");
	
	MessageText = ?(Result,  NStr("en = 'Test has been successfully performed.%AdditionalDetails%'"),
	                               NStr("en = 'Test has been failed. %AdditionalDetails%'"));
	MessageText = StrReplace(MessageText, "%AdditionalDetails%", ?(IsBlankString(AdditionalDetails),
	                             "", Chars.LF + AdditionalDetails));
	CommonUseClientServer.MessageToUser(MessageText);

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure UpdateInformationAboutDriver()

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port", Port);
	tempDeviceParameters.Insert("Speed", Speed);
	tempDeviceParameters.Insert("Parity", 0);
	tempDeviceParameters.Insert("DataBits", 8);
	tempDeviceParameters.Insert("StopBits", 1);
	If EquipmentManagerClient.RunAdditionalCommand("GetDriverVersion",
	                                                               InputParameters,
	                                                               Output_Parameters,
	                                                               ID,
	                                                               tempDeviceParameters) Then
		Driver = Output_Parameters[0];
		Version  = Output_Parameters[1];
	Else
		Driver = Output_Parameters[2];
		Version  = NStr("en='Not defined'");
	EndIf;

	Items.Driver.TextColor = ?(Driver = NStr("en='Not set'"), ErrorColor, TextColor);
	Items.Version.TextColor  = ?(Version  = NStr("en='Not defined'"), ErrorColor, TextColor);

	Items.SetupDriver.Enabled = Not (Driver = NStr("en='Installed'"));

EndProcedure

&AtClient
Procedure SetEnabledOfItems()

	Items.Port.Enabled       = True;
	Items.Speed.Enabled   = True;
	Items.Parity.Enabled   = True;
	Items.DataBits.Enabled = True;
	Items.StopBits.Enabled   = True;
	
EndProcedure

#EndRegion