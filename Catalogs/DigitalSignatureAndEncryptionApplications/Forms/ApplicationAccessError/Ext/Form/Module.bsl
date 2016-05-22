
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Title = Parameters.FormTitle;
	
	// Setting the minimum form width.
	MinimumWidth = StrLen(Title);
	
	InfobaseUserWithFullAccess = Users.InfobaseUserWithFullAccess(,, False);
	
	ErrorOnClient = Parameters.ErrorOnClient;
	ErrorOnServer = Parameters.ErrorOnServer;
	
	If ValueIsFilled(ErrorOnClient)
	   AND ValueIsFilled(ErrorOnServer) Then
		
		ErrorDescription =
			  NStr("en = 'ON SERVER:'")
			+ Chars.LF + Chars.LF + ErrorOnServer.ErrorDescription
			+ Chars.LF + Chars.LF
			+ NStr("en = 'ON COMPUTER:'")
			+ Chars.LF + Chars.LF + ErrorOnClient.ErrorDescription;
	Else
		ErrorDescription = ErrorOnClient.ErrorDescription;
	EndIf;
	
	ErrorDescription = TrimAll(ErrorDescription);
	Items.ErrorDescription.Title = ErrorDescription;
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
		SystemInfo = New SystemInfo;
		AppVersion = SystemInfo.AppVersion;
		If CommonUseClientServer.CompareVersions(AppVersion, "8.3.6.0") > 0 Then
			CompressionFactor = 0.78;
		Else
			CompressionFactor = 0.71;
		EndIf;
	Else
		CompressionFactor = 0.75;
	EndIf;
	
	For LineNumber = 1 To StrLineCount(ErrorDescription) Do
		CurrentRow = StrGetLine(ErrorDescription, LineNumber);
		CurrentStringLength = Int(StrLen(CurrentRow)*CompressionFactor);
		If CurrentStringLength > MinimumWidth Then
			MinimumWidth = CurrentStringLength;
		EndIf;
	EndDo;
	
	Width = ?(MinimumWidth <= 75, MinimumWidth, 75);
	
	ShowInstruction                = Parameters.ShowInstruction;
	ShowTransferToApplicationsSetup = Parameters.ShowTransferToApplicationsSetup;
	ShowExtensionInstallation       = Parameters.ShowExtensionInstallation;
	
	DefineOpportunities(ShowInstruction, ShowTransferToApplicationsSetup, ShowExtensionInstallation,
		ErrorOnClient, InfobaseUserWithFullAccess);
	
	DefineOpportunities(ShowInstruction, ShowTransferToApplicationsSetup, ShowExtensionInstallation,
		ErrorOnServer, InfobaseUserWithFullAccess);
	
	If Not ShowInstruction Then
		Items.GroupInstruction.Visible = False;
	EndIf;
	
	ShowExtensionInstallation = ShowExtensionInstallation AND Not Parameters.ExtensionAttached;
	
	If Not ShowExtensionInstallation Then
		Items.FormSetExtension.Visible = False;
	EndIf;
	
	If Not ShowTransferToApplicationsSetup Then
		Items.FormGoToProramsSetup.Visible = False;
	EndIf;
	
	If ShowInstruction Or ShowExtensionInstallation AND ShowTransferToApplicationsSetup Then
		If Width < 55 Then
			Width = 55;
		EndIf;
	EndIf;
	
	UnsetWindowSizeAndLocation();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure InstructionClick(Item)
	
	DigitalSignatureServiceClient.OpenInstructionForWorkWithApplications();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure GoToApllicationSetup(Command)
	
	Close();
	DigitalSignatureClient.OpenDigitalSignaturesAndEncryptionSettings("application");
	
EndProcedure

&AtClient
Procedure SetExtension(Command)
	
	DigitalSignatureClient.SetExtension(True);
	Close();
	
EndProcedure

&AtClient
Procedure CopyIntoExchangeBuffer(Command)
	
	String = Items.ErrorDescription.Title;
	ShowInputString(New NotifyDescription("CopyIntoExchangeBufferEnd", ThisObject),
		String, NStr("en = 'Error text for copying'"),, True);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure CopyIntoExchangeBufferEnd(Result, NotSpecified) Export
	
	Result = "";
	
EndProcedure

&AtServer
Procedure UnsetWindowSizeAndLocation()
	
	UserName = InfobaseUsers.CurrentUser().Name;
	
	If AccessRight("SaveUserData", Metadata) Then
		SystemSettingsStorage.Delete("CommonForm.Question", "", UserName);
	EndIf;
	
	WindowOptionsKey = String(New UUID);
	
EndProcedure

&AtServer
Procedure DefineOpportunities(Instruction, ApplicationsSetting, Extension, Error, InfobaseUserWithFullAccess)
	
	DefineOpportunitiesForProperties(Instruction, ApplicationsSetting, Extension, Error, InfobaseUserWithFullAccess);
	
	If Not Error.Property("Errors") Or TypeOf(Error.Errors) <> Type("Array") Then
		Return;
	EndIf;
	
	For Each CurrentError IN Error.Errors Do
		DefineOpportunitiesForProperties(Instruction, ApplicationsSetting, Extension, CurrentError, InfobaseUserWithFullAccess);
	EndDo;
	
EndProcedure

&AtServer
Procedure DefineOpportunitiesForProperties(Instruction, ApplicationsSetting, Extension, Error, InfobaseUserWithFullAccess)
	
	If Error.Property("ApplicationsSetting") AND Error.ApplicationsSetting = True Then
		ApplicationsSetting = InfobaseUserWithFullAccess
			Or Not Error.Property("ToAdmin")
			Or Error.ToAdmin <> True;
	EndIf;
	
	If Error.Property("Instruction") AND Error.Instruction = True Then
		Instruction = True;
	EndIf;
	
	If Error.Property("Extension") AND Error.Extension = True Then
		Extension = True;
	EndIf;
	
EndProcedure

#EndRegion
