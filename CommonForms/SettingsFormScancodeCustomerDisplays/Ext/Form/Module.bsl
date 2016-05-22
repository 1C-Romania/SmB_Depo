﻿
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
	ListModel.Add(0, "DSP860");
	ListModel.Add(1, "DSP850B");
	ListModel.Add(2, "DSP840");
	ListModel.Add(3, "DSP820");
	ListModel.Add(4, "Firich FV2029");
	
	SpeedList = Items.Speed.ChoiceList;
	SpeedList.Add(9600,  "9600");

	tempPort     = Undefined;
	tempSpeed = Undefined;
	tempModel   = Undefined;
	
	Parameters.EquipmentParameters.Property("Port",    tempPort);
	Parameters.EquipmentParameters.Property("Speed",   tempSpeed);
	Parameters.EquipmentParameters.Property("Model",   tempModel);
	
	Port     = ?(tempPort  = Undefined,    1, tempPort);
	Speed    = ?(tempSpeed = Undefined, 9600, tempSpeed);
	Model    = ?(tempModel = Undefined,    0, tempModel);
	
	Items.DeviceTest.Visible = (SessionParameters.ClientWorkplace = ID.Workplace);
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
	ParametersNewValue.Insert("Port"    , Port);
	ParametersNewValue.Insert("Speed"   , Speed);
	ParametersNewValue.Insert("Model"   , Model);
	
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

	InputParameters   = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"						, Port);
	tempDeviceParameters.Insert("Speed"       	, Speed);
	tempDeviceParameters.Insert("Parity"					, 0);
	tempDeviceParameters.Insert("DataBits"				, 8);
	tempDeviceParameters.Insert("StopBits"		 	, 1);
	tempDeviceParameters.Insert("Model"				 	, Model);
	
	Result = EquipmentManagerClient.RunAdditionalCommand("CheckHealth",
	                                                                      InputParameters,
	                                                                      Output_Parameters,
	                                                                      ID,
	                                                                      tempDeviceParameters);

	If Result Then
		MessageText = NStr("en = 'Test successfully performed.'");
		CommonUseClientServer.MessageToUser(MessageText);
	Else
		AdditionalDetails = ?(TypeOf(Output_Parameters) = Type("Array")
		                           AND Output_Parameters.Count() >= 2,
		                           NStr("en = 'Additional description:'") + " " + Output_Parameters[1],
		                           "");


		MessageText = NStr("en = 'Test failed.%Linefeed% %AdditionalDetails%'");
		MessageText = StrReplace(MessageText, "%Linefeed%", ?(IsBlankString(AdditionalDetails),
		                                                                  "",
		                                                                  Chars.LF));
		MessageText = StrReplace(MessageText, "%AdditionalDetails%", ?(IsBlankString(AdditionalDetails),
		                                                                           "",
		                                                                           AdditionalDetails));
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetEnabledOfItems()

	Items.Port.Enabled            = True;
	Items.Speed.Enabled           = True;

EndProcedure

&AtClient
Procedure UpdateInformationAboutDriver()

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"       	, Port);
	tempDeviceParameters.Insert("Speed"     		, Speed);
	tempDeviceParameters.Insert("Parity"				, 0);
	tempDeviceParameters.Insert("DataBits"			, 8);
	tempDeviceParameters.Insert("StopBits"			, 1);
	tempDeviceParameters.Insert("Model"					, Model);
	
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

#EndRegion