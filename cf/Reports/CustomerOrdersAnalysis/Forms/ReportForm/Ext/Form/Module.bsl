
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
//  Replaces account documents when report call by mutual settlements from receipt
//  If receipt by purchase order - the settlement document is the purchase order
//
//  Parameters:
//  Parameters - FormDataStructure - Report parameters
//
Procedure SetSelectionReport(Parameters) Export
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("CustomerOrder") Then
		
		ParameterCustomerOrder = Parameters.Filter.CustomerOrder;
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED DISTINCT
		|	AcceptanceCertificateWorksAndServices.CustomerOrder
		|FROM
		|	Document.AcceptanceCertificate.WorksAndServices AS AcceptanceCertificateWorksAndServices
		|WHERE
		|	AcceptanceCertificateWorksAndServices.Ref IN(&ParameterCustomerOrder)
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	CustomerInvoiceInventory.Order
		|FROM
		|	Document.CustomerInvoice.Inventory AS CustomerInvoiceInventory
		|WHERE
		|	CustomerInvoiceInventory.Ref IN(&ParameterCustomerOrder)
		|";
		If AccessRight("Read", Metadata.Documents.InventoryReservation) Then
			Query.Text = Query.Text + "
			|UNION ALL
			|
			|SELECT DISTINCT
			|	InventoryReservation.CustomerOrder
			|FROM
			|	Document.InventoryReservation AS InventoryReservation
			|WHERE
			|	InventoryReservation.Ref IN(&ParameterCustomerOrder)
			|";
		EndIf;
		Query.Text = Query.Text + "
		|UNION ALL
		|
		|SELECT DISTINCT
		|	CustomerOrder.Ref
		|FROM
		|	Document.CustomerOrder AS CustomerOrder
		|WHERE
		|	CustomerOrder.Ref IN(&ParameterCustomerOrder)";
		
		Query.SetParameter("ParameterCustomerOrder", ParameterCustomerOrder);
		
		ResultTable 				= Query.Execute().Unload();
		Parameters.Filter.CustomerOrder = ResultTable.UnloadColumn("CustomerOrder");
		
	EndIf;
	
EndProcedure // ReplaceAccountDocumentsWithSuppliers()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
//  Procedure - form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Report.FilterByOrderStatuses = Items.FilterByOrderStatuses.ChoiceList[0].Value;
	
	If Parameters.Property("Filter")
		AND Parameters.Filter.Property("CustomerOrder") Then
		
		Items.FilterByOrderStatuses.Enabled = False;
		SetSelectionReport(Parameters);
	
	EndIf;
	
	Parameters.GenerateOnOpen = True;

EndProcedure // OnCreateAtServer()

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	ReportsVariants.OnSaveUserSettingsAtServer(ThisObject, Settings);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - HANDLERS OF THE FORM COMMANDS EVENTS

&AtClient
//Procedure event handler OnChange of the FilterByOrderStatuses attribute 
//
Procedure FilterByOrderStatusesOnChange(Item)
	
	ComposeResult();
	
EndProcedure //FilterByOrderStatusesOnChange()
//














