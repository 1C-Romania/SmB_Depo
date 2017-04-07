
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("FilterParameters") Then
		OrdersList = Parameters.FilterParameters.FilterOrders;
		RepetitionFactorOFDay = Parameters.FilterParameters.RepetitionFactorOFDay;
		TimeLimitTo = Parameters.FilterParameters.TimeLimitTo;
		TimeLimitFrom = Parameters.FilterParameters.TimeLimitFrom;
		ShowJobOrders = Parameters.FilterParameters.ShowJobOrders;
		ShowProductionOrders = Parameters.FilterParameters.ShowProductionOrders;
		SmallBusinessClientServer.SetListFilterItem(List, "Ref", OrdersList, True, DataCompositionComparisonType.InList);
	EndIf;
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
EndProcedure // OnCreateAtServer()

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	If Items.List.CurrentRow = Undefined Then
		Items.KMListChange.Enabled = False;
		Items.ListChange.Enabled = False;
	EndIf;
	
EndProcedure // OnOpen()

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Key", SelectedRow);
	OpenParameters.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
	OpenParameters.Insert("TimeLimitTo", TimeLimitTo);
	OpenParameters.Insert("TimeLimitFrom", TimeLimitFrom);
	OpenParameters.Insert("ShowJobOrders", ShowJobOrders);
	OpenParameters.Insert("ShowProductionOrders", ShowProductionOrders);
	
	If TypeOf(SelectedRow) = Type("DocumentRef.ProductionOrder") Then
		OpenForm("Document.ProductionOrder.Form.RequestForm", OpenParameters, Items.List,,,,,FormWindowOpeningMode.LockOwnerWindow);
	Else
		OpenForm("Document.CustomerOrder.Form.RequestForm", OpenParameters, Items.List,,,,,FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

&AtClient
Procedure Change(Command)
	
	SelectedRow = Items.List.CurrentRow;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Key", SelectedRow);
	OpenParameters.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
	OpenParameters.Insert("TimeLimitTo", TimeLimitTo);
	OpenParameters.Insert("TimeLimitFrom", TimeLimitFrom);
	OpenParameters.Insert("ShowJobOrders", ShowJobOrders);
	OpenParameters.Insert("ShowProductionOrders", ShowProductionOrders);
	
	If TypeOf(SelectedRow) = Type("DocumentRef.ProductionOrder") Then
		OpenForm("Document.ProductionOrder.Form.RequestForm", OpenParameters, Items.List,,,,,FormWindowOpeningMode.LockOwnerWindow);
	Else
		OpenForm("Document.CustomerOrder.Form.RequestForm", OpenParameters, Items.List,,,,,FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure









