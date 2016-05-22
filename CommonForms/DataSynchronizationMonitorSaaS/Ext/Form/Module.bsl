
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess(Undefined, True, False) Then
		Raise NStr("en = 'No rights to administrate the data exchange.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	RefreshNodeStateList();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

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
Procedure RefreshNodeStateList()
	
	NodeStateList.Clear();
	
	NodeStateList.Load(
		DataExchangeSaaS.DataExchangeMonitorTable(DataExchangeReUse.SeparatedSSLExchangePlans()));
	
EndProcedure

&AtClient
Procedure RefreshMonitorData()
	
	NodeStateListRowIndex = GetRowCurrentIndex("NodeStateList");
	
	// update the monitor tables on server
	RefreshNodeStateList();
	
	// Determining the cursor position
	RunCursorPositioning("NodeStateList", NodeStateListRowIndex);
	
EndProcedure

&AtClient
Function GetRowCurrentIndex(TableName)
	
	// Return value
	RowIndex = Undefined;
	
	// Determining the cursor position during the monitor update
	CurrentData = Items[TableName].CurrentData;
	
	If CurrentData <> Undefined Then
		
		RowIndex = ThisObject[TableName].IndexOf(CurrentData);
		
	EndIf;
	
	Return RowIndex;
EndFunction

&AtClient
Procedure RunCursorPositioning(TableName, RowIndex)
	
	If RowIndex <> Undefined Then
		
		// Checking the cursor position once new data is received
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
	
	Items.NodeStateListLastSuccessfulExportDate.Visible = Items.NodeStateListDetailed.Check;
	Items.NodeStateListLastSuccessfulImportDate.Visible = Items.NodeStateListDetailed.Check;
	Items.NodeStateListExchangePlanName.Visible = Items.NodeStateListDetailed.Check;
	
EndProcedure

#EndRegion
