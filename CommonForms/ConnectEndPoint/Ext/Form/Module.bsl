
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	EndPointConnectionEventLogMonitorMessageText = MessageExchangeInternal.EndPointConnectionEventLogMonitorMessageText();
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	WarningText = NStr("en='Do you want to cancel the connection to the end point?';ru='Отменить подключение конечной точки?'");
	Notification = New NotifyDescription("ConnectAndClose", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel, WarningText);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ToConnectEndPoint(Command)
	
	ConnectAndClose();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ConnectAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	Status(NStr("en='End point is being connected. Please wait...';ru='Выполняется подключение конечной точки. Пожалуйста, подождите..'"));
	
	Cancel = False;
	FillError = False;
	
	ConnectEndPointAtServer(Cancel, FillError);
	
	If FillError Then
		Return;
	EndIf;
	
	If Cancel Then
		
		NString = NStr("en='There were errors when connecting to the end point.
		|Do you want to open the event log?';ru='При подключении конечной точки возникли ошибки.
		|Перейти в журнал регистрации?'");
		NotifyDescription = New NotifyDescription("OpenEventLogMonitor", ThisObject);
		ShowQueryBox(NOTifyDescription, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		Return;
	EndIf;
	
	Notify(MessageExchangeClient.EndPointAddedEventName());
	
	ShowUserNotification(,,NStr("en='End point connection has been successfully completed.';ru='Подключение конечной точки успешно завершено.'"));
	
	Modified = False;
	
	Close();
	
EndProcedure

&AtClient
Procedure OpenEventLogMonitor(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogMonitorEvent", EndPointConnectionEventLogMonitorMessageText);
		OpenForm("DataProcessor.EventLogMonitor.Form", Filter, ThisObject);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ConnectEndPointAtServer(Cancel, FillError)
	
	If Not CheckFilling() Then
		FillError = True;
		Return;
	EndIf;
	
	MessageExchange.ToConnectEndPoint(
		Cancel,
		SenderSettingsWSURLWebService,
		SenderSettingsWSUserName,
		SenderSettingsWSPassword,
		RecipientSettingsWSURLWebService,
		RecipientSettingsWSUserName,
		RecipientSettingsWSPassword);
	
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
