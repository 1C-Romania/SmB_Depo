
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	MarkedObjectDeletion = Parameters.MarkedObjectDeletion;
	If MarkedObjectDeletion Then
		Title = NStr("en='Failed to delete the objects marked for deletion';ru='Не удалось выполнить удаление помеченных объектов'");
		Items.ErrorMessageText.Title = NStr("en='You can not delete objects marked for deletion as other users work in application:';ru='Невозможно выполнить удаление помеченных объектов, т.к. в программе работают другие пользователи:'");
	EndIf;
	
	ActiveUsersTemplate = NStr("en='Active users (%1)';ru='Активные пользователи (%1)'");
	
	ActiveConnectionCount = InfobaseConnections.InfobaseSessionCount();
	Items.ActiveUsers.Title = StringFunctionsClientServer.
		PlaceParametersIntoString(ActiveUsersTemplate, ActiveConnectionCount);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	AttachIdleHandler("RefreshActiveSessionCount", 30);
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ActiveUsersClick(Item)
	
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm", New Structure("ExclusiveModeSetupError"));
	
EndProcedure

&AtClient
Procedure ActiveUsers2Click(Item)
	
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm");
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CompleteSessionsAndRestartApplication(Command)
	
	Items.GroupPages.CurrentPage = Items.Page2;
	AssistantCurrentPage = "Page2";
	Items.FormRetryApplicationStart.Visible = False;
	Items.FormCompleteSessionsAndRestartApplication.Visible = False;
	
	// Setting IB lock parameters.
	RefreshActiveSessionCount();
	InstallLockOfFileBase();
	InfobaseConnectionsClient.SetIdleHandlerOfUserSessionsTermination(True);
	AttachIdleHandler("TimeOutCompleteWorkUsers", 60);
	
EndProcedure

&AtClient
Procedure CancelApplicationStart(Command)
	
	UnlockFileBase();
	
	Close(True);
	
EndProcedure

&AtClient
Procedure RetryRunApplication(Command)
	
	Close(False);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure RefreshActiveSessionCount()
	
	Result = RefreshEnabledNumberOfActiveSessionsAtServer();
	If Result Then
		Close(False);
	EndIf;
	
EndProcedure

&AtServer
Function RefreshEnabledNumberOfActiveSessionsAtServer()
	
	If AssistantCurrentPage = "Page2" Then
		ActiveUsers = "ActiveUsers2";
	Else
		ActiveUsers = "ActiveUsers";
	EndIf;

	InfobaseSessions = GetInfobaseSessions();
	ActiveConnectionCount = InfobaseSessions.Count();
	Items[ActiveUsers].Title = StringFunctionsClientServer.
		PlaceParametersIntoString(ActiveUsersTemplate, ActiveConnectionCount);
	
	QuantityOfSessionImpedingToUpdate = 0;
	For Each InfobaseSession IN InfobaseSessions Do
		
		If InfobaseSession.ApplicationName = "Designer" Then
			Continue;
		EndIf;
		
		QuantityOfSessionImpedingToUpdate = QuantityOfSessionImpedingToUpdate + 1;
	EndDo;
	
	If QuantityOfSessionImpedingToUpdate = 1 Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

&AtClient
Procedure TimeOutCompleteWorkUsers()
	
	DurationOfUsersWorkCompletion = DurationOfUsersWorkCompletion + 1;
	
	If DurationOfUsersWorkCompletion >= 3 Then
		UnlockFileBase();
		Items.GroupPages.CurrentPage = Items.Page1;
		AssistantCurrentPage = "Page1";
		Items.ErrorMessageText.Title = NStr("en='Cannot upgrade the application version as it failed to close the sessions of users:';ru='Невозможно выполнить обновление версии программы, т.к. не удалось завершить работу пользователей:'");
		Items.FormRetryApplicationStart.Visible = True;
		Items.FormCompleteSessionsAndRestartApplication.Visible = True;
		DetachIdleHandler("TimeOutCompleteWorkUsers");
		DurationOfUsersWorkCompletion = 0;
	EndIf;
	
EndProcedure

&AtServer
Procedure InstallLockOfFileBase()
	
	Object.ProhibitUserWorkTemporarily = True;
	If MarkedObjectDeletion Then
		Object.LockBegin = CurrentSessionDate() + 2*60;
		Object.LockEnding = Object.LockBegin + 60;
		Object.MessageForUsers = NStr("en='Application is locked to delete marked objects.';ru='Программа заблокирована для удаления помеченных объектов.'");
	Else
		Object.LockBegin = CurrentSessionDate() + 2*60;
		Object.LockEnding = Object.LockBegin + 5*60;
		Object.MessageForUsers = NStr("en='Application is locked to perform the update.';ru='Программа заблокирована для выполнения обновления.'");
	EndIf;
	
	Try
		FormAttributeToValue("Object").RunSetup();
	Except
		WriteLogEvent(InfobaseConnectionsClientServer.EventLogMonitorEvent(),
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		CommonUseClientServer.MessageToUser(ErrorShortInfo(ErrorDescription()), , );
	EndTry;
	
EndProcedure

&AtServer
Procedure UnlockFileBase()
	
	FormAttributeToValue("Object").Unlock();
	
EndProcedure

&AtServer
Function ErrorShortInfo(ErrorDescription)
	
	ErrorText = ErrorDescription;
	Position = Find(ErrorText, "}:");
	If Position > 0 Then
		ErrorText = TrimAll(Mid(ErrorText, Position + 2, StrLen(ErrorText)));
	EndIf;
	
	Return ErrorText;
EndFunction

#EndRegion














