////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - Form commands actions

&AtClient
Procedure Open1CTaxcomServiceConnectionAssistant(Command)
	
	ElectronicDocumentsClient.ConnectionAssistant1CTaxcomService();
	
EndProcedure

&AtClient
Procedure OpenDirectExchangeConnectionAssistant(Command)
	
	ElectronicDocumentsClient.DirectExchangeConnectionAssistant();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshStateED" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure AuthenticateToServerOnChange(Item)
	
	SetContextAuthenticationOnServer(AuthenticateToServer);
	
	Notify("Record_ConstantsSet", New Structure, "AuthorizationContext");
	
EndProcedure

&AtServerNoContext
Procedure SetContextAuthenticationOnServer(AuthenticateToServer)
	
	SelectedVariant = ?(AuthenticateToServer,
		Enums.WorkContextsWithED.AtServer, Enums.WorkContextsWithED.AtClient);
	If Not AccessRight("Set", Metadata.Constants.AuthorizationContext)
	 Or Constants.AuthorizationContext.Get() = SelectedVariant Then
		
		Return;
	EndIf;
	
	Constants.AuthorizationContext.Set(SelectedVariant);
	
	// It is required to update common settings at server and on client.
	RefreshReusableValues();
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		SetContextAuthenticationOnServer(False);
		Items.AuthenticateToServer.Visible = False;
	Else
		AuthenticateToServer = (Constants.AuthorizationContext.Get() = Enums.WorkContextsWithED.AtServer);
	EndIf;
	
	RunMode = CommonUseReUse.ApplicationRunningMode();
	
	If Not RunMode.IsApplicationAdministrator Then
		Items.AuthenticateToServer.Visible = False;
	EndIf;
	
EndProcedure
