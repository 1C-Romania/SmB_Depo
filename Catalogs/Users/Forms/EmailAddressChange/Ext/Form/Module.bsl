#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	User = Parameters.User;
	ServiceUserPassword = Parameters.ServiceUserPassword;
	OldEmail = Parameters.OldEmail;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ChangeEmailAddress(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	QuestionText = "";
	If Not ValueIsFilled(OldEmail) Then
		QuestionText =
			NStr("en = 'Email address of service user is changed.
			           |The subscriber owners or administrators will not be able to change the user parameters any more.'")
			+ Chars.LF
			+ Chars.LF;
	EndIf;
	QuestionText = QuestionText + NStr("en = 'Do you want to change the email address?'");
	
	ShowQueryBox(
		New NotifyDescription("ChangeEmailEnd", ThisObject),
		QuestionText,
		QuestionDialogMode.YesNoCancel);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure CreateRequestToChangeEmail()
	
	UsersService.WhenYouCreateQueryByMail(NewEmail, User, ServiceUserPassword);
	
EndProcedure

&AtClient
Procedure ChangeEmailEnd(Response, NotSpecified) Export
	
	If Response = DialogReturnCode.Yes Then
		
		CreateRequestToChangeEmail();
		
		ShowMessageBox(
			New NotifyDescription("Close", ThisObject),
			NStr("en = 'The email with confirmation request was sent to the specified address.
			           |Email will be changed only after confirmation of the request by a user.'"));
		
	ElsIf Response = DialogReturnCode.No Then
		Close();
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
