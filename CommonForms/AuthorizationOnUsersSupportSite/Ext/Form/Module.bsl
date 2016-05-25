
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Authentication = StandardSubsystemsServer.AuthenticationParametersOnSite();
	If Authentication <> Undefined Then
		Login  = Authentication.Login;
		Password = Authentication.Password;
	EndIf;
	
	RememberPassword = Not IsBlankString(Password);
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure GoToRegistrationOnSitePress(Item)
	
	GotoURL("https://1c-dn.com/user/updates/");
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure AuthenticationDataSaveAndContinue()
	
	If IsBlankString(Login) AND Not IsBlankString(Password) Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Enter code of user for authorization on a 1C firm website.'"),, "Login");
		Return;
	EndIf;
		
	If IsBlankString(Login) Then
		SaveAuthenticationData(Undefined);
		Result = DialogReturnCode.Cancel;
	Else
		SaveAuthenticationData(New Structure("Login,Password", Login, ?(RememberPassword, Password, "")));
		Result = New Structure("Login,Password", Login, Password);
	EndIf;
	
	Close(Result);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Procedure SaveAuthenticationData(Val Authentication)
	
	StandardSubsystemsServer.SaveAuthenticationParametersOnSite(Authentication);
	
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
