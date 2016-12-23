

&AtClient
Var PermissionsReceived;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.LockOwner Then
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		Object.UseForSending = True;
		Object.UseForReceiving = True;
	EndIf;
	
	DeleteEmailsFromServer = Object.ServerEmailStoragePeriod > 0;
	If Not DeleteEmailsFromServer Then
		Object.ServerEmailStoragePeriod = 10;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	NotifyDescription = New NotifyDescription("BeforeCloseConfirmationIsReceived", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(NOTifyDescription, Cancel);
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not DeleteEmailsFromServer Then
		Object.ServerEmailStoragePeriod = 0;
	EndIf;
	
	If Object.IncomingMailProtocol = "IMAP" Then
		Object.LeaveMessageCopiesOnServer = True;
		Object.ServerEmailStoragePeriod = 0;
	EndIf;
	
	If PermissionsReceived <> True Then
		If Not CheckFilling() Then 
			Cancel = True;
			Return;
		EndIf;
		
		Query = CreateQueryOnExternalResourcesUse();
		ClosingAlert = New NotifyDescription("GetPermissionsEnd", ThisObject, WriteParameters);
		
		WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(
			CommonUseClientServer.ValueInArray(Query), ThisObject, ClosingAlert);
		
		Cancel = True;
	EndIf;
	PermissionsReceived = False;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	If WriteParameters.Property("WriteAndClose") Then
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetEnabledOfItems();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ProtocolOnChange(Item)
	
	If Object.IncomingMailProtocol = "IMAP" Then
		If Left(Object.IncomingMailServer, 4) = "pop." Then
			Object.IncomingMailServer = "imap." + Mid(Object.IncomingMailServer, 5);
		EndIf
	Else
		If IsBlankString(Object.IncomingMailProtocol) Then
			Object.IncomingMailProtocol = "POP";
		EndIf;
		If Left(Object.IncomingMailServer, 5) = "imap." Then
			Object.IncomingMailServer = "pop." + Mid(Object.IncomingMailServer, 6);
		EndIf;
	EndIf;
	
	SetIncomingMailPort();
	SetEnabledOfItems();
EndProcedure

&AtClient
Procedure IncomingMailServerOnChange(Item)
	Object.IncomingMailServer = TrimAll(Lower(Object.IncomingMailServer));
EndProcedure

&AtClient
Procedure OutgoingMailServerOnChange(Item)
	Object.OutgoingMailServer = TrimAll(Lower(Object.OutgoingMailServer));
EndProcedure

&AtClient
Procedure EmailAddressOnChange(Item)
	Object.EmailAddress = TrimAll(Object.EmailAddress);
EndProcedure

&AtClient
Procedure UseSecureConnectionForOutgoingMailOnChange(Item)
	SetOutgoingMailPort();
EndProcedure

&AtClient
Procedure UseSecureConnectionForIncomingMailOnChange(Item)
	SetIncomingMailPort();
EndProcedure

&AtClient
Procedure KeepEmailCopiesOnServerOnChange(Item)
	SetEnabledOfItems();
EndProcedure

&AtClient
Procedure DeleteEmailsFromServerOnChange(Item)
	SetEnabledOfItems();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	Write(New Structure("WriteAndClose"));
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetIncomingMailPort()
	If Object.IncomingMailProtocol = "IMAP" Then
		If Object.UseSecureConnectionForIncomingMail Then
			Object.IncomingMailServerPort = 993;
		Else
			Object.IncomingMailServerPort = 143;
		EndIf;
	Else
		If Object.UseSecureConnectionForIncomingMail Then
			Object.IncomingMailServerPort = 995;
		Else
			Object.IncomingMailServerPort = 110;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure SetOutgoingMailPort()
	If Object.UseSecureConnectionForOutgoingMail Then
		Object.OutgoingMailServerPort = 465;
	Else
		Object.OutgoingMailServerPort = 25;
	EndIf;
EndProcedure

&AtClient
Procedure BeforeCloseConfirmationIsReceived(QuestionResult, AdditionalParameters) Export
	Write(New Structure("WriteAndClose"));
EndProcedure

&AtClient
Procedure SetEnabledOfItems()
	POPProtocolIsUsed = Object.IncomingMailProtocol = "POP";
	Items.POPBeforeSMTP.Visible = POPProtocolIsUsed;
	Items.KeepMessagesOnServer.Visible = POPProtocolIsUsed;
	
	Items.StoragePeriodSetup.Enabled = Object.LeaveMessageCopiesOnServer;
	Items.ServerEmailStoragePeriod.Enabled = DeleteEmailsFromServer;
EndProcedure

&AtClient
Procedure GetPermissionsEnd(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.OK Then
		PermissionsReceived = True;
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtServer
Function CreateQueryOnExternalResourcesUse()
	
	Return WorkInSafeMode.QueryOnExternalResourcesUse(
		permissions(), Object.Ref);
	
EndFunction

&AtServer
Function permissions()
	
	Result = New Array;
	
	If Object.UseForSending Then
		Result.Add(
			WorkInSafeMode.PermissionForWebsiteUse(
				"SMTP",
				Object.OutgoingMailServer,
				Object.OutgoingMailServerPort,
				NStr("en='Email.';ru='Эл. адрес.'")));
	EndIf;
	
	If Object.UseForReceiving Then
		Result.Add(
			WorkInSafeMode.PermissionForWebsiteUse(
				Object.IncomingMailProtocol,
				Object.IncomingMailServer,
				Object.IncomingMailServerPort,
				NStr("en='Email.';ru='Эл. адрес.'")));
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion














