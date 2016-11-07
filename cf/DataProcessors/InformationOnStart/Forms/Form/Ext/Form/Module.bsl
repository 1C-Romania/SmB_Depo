#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	//CurrentLineIndex = -1;
	//BaseConfiguration       = StandardSubsystemsServer.ThisIsBasicConfigurationVersion();
	//ConfigurationSaaS = CommonUseReUse.DataSeparationEnabled();
	//If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
	//	ModuleDataExchangeReUse = CommonUse.CommonModule("DataExchangeReUse");
	//	ConfigurationSaaS = ConfigurationSaaS Or ModuleDataExchangeReUse.ThisIsOfflineWorkplace();
	//EndIf;
	//
	//StandardPrefix = GetInfobaseURL() + "/";
	//ThisIsWebClient = Find(StandardPrefix, "http://") > 0;
	//If ThisIsWebClient Then
	//	LocaleCode = CurrentLocaleCode();
	//	StandardPrefix = StandardPrefix + LocaleCode + "/";
	//EndIf;
	//
	DataSavingRight = AccessRight("SaveUserData", Metadata);
	
	If BaseConfiguration Or Not DataSavingRight Then
		Items.ShowOnWorkStart.Visible = False;
	Else
		ShowOnWorkStart = True;
	EndIf;
	//
	//NoDataForDisplay = False;
	//
	//If Not PrepareFormData() Then
	//	
	//	NoDataForDisplay = True;
	//	
	//EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	If Not BaseConfiguration AND DataSavingRight Then
		SaveFlagState(ShowOnWorkStart);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Forward(Command)
	//PageView("Forward", Undefined);
EndProcedure

&AtClient
Procedure Back(Command)
	//PageView("Back", Undefined);
EndProcedure

&AtClient
Procedure Command_Support(Command)
	GotoURL("http://1c-dn.com");
EndProcedure

&AtClient
Procedure Command_Learn1CEnterprise(Command)
	GotoURL("http://1c-dn.com/learning/");             
EndProcedure

&AtClient
Procedure Command_SupportForum(Command)
	GotoURL("http://1c-dn.com/forum/forum9/");
EndProcedure

&AtClient
Procedure Command_StandardSolutions(Command)
	GotoURL("http://1c-dn.com/applications/");
EndProcedure

&AtClient
Procedure Command_IndustrySolutions(Command)
	GotoURL("http://v8.1c.ru/metod/books/files/1C-Enterprise.pdf");
EndProcedure

&AtClient
Procedure Command_Compatible1C(Command)
	GotoURL("http://1c-dn.com/blogs/partnerblog/20/");
EndProcedure

&AtClient
Procedure Command_Manuals1CEnterprise(Command)
	GotoURL(" http://1c-dn.com/1c_enterprise/");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Procedure SaveFlagState(ShowOnWorkStart)
	CommonUse.CommonSettingsStorageSave("InformationOnStart", "Show", ShowOnWorkStart);
	If Not ShowOnWorkStart Then
		DateOfNearestShow = BegOfDay(CurrentSessionDate() + 14*24*60*60);
		CommonUse.CommonSettingsStorageSave("InformationOnStart", "DateOfNearestShow", DateOfNearestShow);
	EndIf;
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
