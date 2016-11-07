
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData() Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en='Subsystem setup is not supported in the separated mode.';ru='Настройка подсистемы в разделенном режиме не поддерживается.'"),,,, Cancel);
		Return;
	EndIf;
	
	RefreshNodeStateList();
	
	SetPrivilegedMode(True);
	
	Items.NodeStateListEnableDisableSendReceiveSystemMessagesSchedule.Check =
		ScheduledJobsServer.GetScheduledJobUse(
			Metadata.ScheduledJobs.SendReceiveSystemMessages);;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If    EventName = MessageExchangeClient.EventNameMessagesSendingAndReceivingPerformed()
		OR EventName = MessageExchangeClient.EndPointFormClosedEventName()
		OR EventName = MessageExchangeClient.EndPointAddedEventName()
		OR EventName = MessageExchangeClient.EventNameLeadingEndPointSet()
		Then
		
		RefreshMonitorData();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ListOfNodesStatusSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ChangeEndPoint(Undefined);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ToConnectEndPoint(Command)
	
	OpenForm("CommonForm.ConnectEndPoint",, ThisObject, 1);
	
EndProcedure

&AtClient
Procedure SetupSubscriptions(Command)
	
	OpenForm("InformationRegister.RecipientSubscriptions.Form.ThisEndPointSubscriptionSetup",, ThisObject);
	
EndProcedure

&AtClient
Procedure SendAndReceiveMessages(Command)
	
	MessageExchangeClient.SendAndReceiveMessages();
	
EndProcedure

&AtClient
Procedure ChangeEndPoint(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ShowValue(, CurrentData.InfobaseNode);
	
EndProcedure

&AtClient
Procedure GoToDataExportEventsEventLogMonitor(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToEventLogMonitorOfDataEventsModalRegistartion(CurrentData.InfobaseNode, ThisObject, "DataExport");
	
EndProcedure

&AtClient
Procedure GoToDataImportEventsEventLogMonitor(Command)
	
	CurrentData = Items.NodeStateList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToEventLogMonitorOfDataEventsModalRegistartion(CurrentData.InfobaseNode, ThisObject, "DataImport");
	
EndProcedure

&AtClient
Procedure ConfigureSystemMessageSendReceiveSchedule(Command)
	
	Dialog = New ScheduledJobDialog(GetSchedule());
	NotifyDescription = New NotifyDescription("SetSystemMessagesSendAndReceiveSchedule", ThisObject);
	Dialog.Show(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure SetSystemMessagesSendAndReceiveSchedule(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		
		SetSchedule(Schedule);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableDisableSendReceiveSystemMessagesSchedule(Command)
	
	EnableDisableSystemMessagesReceivingAndSendingScheduleAtServer();
	
EndProcedure

&AtClient
Procedure RefreshMonitor(Command)
	
	RefreshMonitorData();
	
EndProcedure

&AtClient
Procedure Detailed(Command)
	
	DetailedAtServer();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure EnableDisableSystemMessagesReceivingAndSendingScheduleAtServer()
	
	SetPrivilegedMode(True);
	
	Items.NodeStateListEnableDisableSendReceiveSystemMessagesSchedule.Check =
		Not ScheduledJobsServer.GetScheduledJobUse(
			Metadata.ScheduledJobs.SendReceiveSystemMessages);
	
	ScheduledJobsServer.SetUseScheduledJob(
		Metadata.ScheduledJobs.SendReceiveSystemMessages,
		Items.NodeStateListEnableDisableSendReceiveSystemMessagesSchedule.Check);
	
EndProcedure

&AtServerNoContext
Function GetSchedule()
	
	SetPrivilegedMode(True);
	
	Return ScheduledJobsServer.GetJobSchedule(
		Metadata.ScheduledJobs.SendReceiveSystemMessages);
	
EndFunction

&AtServerNoContext
Procedure SetSchedule(Val Schedule)
	
	SetPrivilegedMode(True);
	
	ScheduledJobsServer.SetJobSchedule(
		Metadata.ScheduledJobs.SendReceiveSystemMessages,
		Schedule);
	
EndProcedure

&AtServer
Procedure RefreshNodeStateList()
	
	NodeStateList.Clear();
	
	Array = New Array;
	Array.Add("MessageExchange");
	
	DataExchangeMonitor = DataExchangeServer.DataExchangeMonitorTable(Array, "Leading,Blocked");
	
	// Update data in nodes state list.
	For Each Setting IN DataExchangeMonitor Do
		
		If Setting.Blocked Then
			Continue;
		EndIf;
		
		FillPropertyValues(NodeStateList.Add(), Setting);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RefreshMonitorData()
	
	NodeStateListRowIndex = GetRowCurrentIndex("NodeStateList");
	
	// Update the monitor tables at the server.
	RefreshNodeStateList();
	
	// Positioning the cursor.
	RunCursorPositioning("NodeStateList", NodeStateListRowIndex);
	
EndProcedure

&AtClient
Function GetRowCurrentIndex(TableName)
	
	// Return value of the function.
	RowIndex = Undefined;
	
	// Determining the cursor position during the monitor update.
	CurrentData = Items[TableName].CurrentData;
	
	If CurrentData <> Undefined Then
		
		RowIndex = ThisObject[TableName].IndexOf(CurrentData);
		
	EndIf;
	
	Return RowIndex;
EndFunction

&AtClient
Procedure RunCursorPositioning(TableName, RowIndex)
	
	If RowIndex <> Undefined Then
		
		// Checking the cursor position after the receipt of new data.
		If ThisObject[TableName].Count() <> 0 Then
			
			If RowIndex > ThisObject[TableName].Count() - 1 Then
				
				RowIndex = ThisObject[TableName].Count() - 1;
				
			EndIf;
			
			// Determining the cursor position
			Items[TableName].CurrentRow = ThisObject[TableName][RowIndex].GetID();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DetailedAtServer()
	
	Items.NodeStateListDetailed.Check = Not Items.NodeStateListDetailed.Check;
	
	Items.NodeStateListLastImportDate.Visible = Items.NodeStateListDetailed.Check;
	Items.NodeStateListLastExportDate.Visible = Items.NodeStateListDetailed.Check;
	
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
