
&AtServer
// Function places picking results into storage
//
Function WritePickToStorage() 
	
	Return PutToTempStorage(FilteredInventory.Unload(FilteredInventory.FindRows(New Structure("Mark", True))));
	
EndFunction //WritePickToStorage() 

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Period 				= Parameters.Period;
	Company 		= Parameters.Company;
	AccountingBySubsidiaryCompany		= Constants.AccountingBySubsidiaryCompany.Get();
	
	If Parameters.Property("DocumentInventoryAddress") Then
		
		InventoryTable = GetFromTempStorage(Parameters.DocumentInventoryAddress);
		
		InventoryTable.Columns.Add("Mark", New TypeDescription("Boolean"));
		InventoryTable.FillValues(True, "Mark");
		
		For Each TSRow IN InventoryTable Do
			
			FillPropertyValues(FilteredInventory.Add(), TSRow);
			
		EndDo;
		
	EndIf; 
	
	If Parameters.Property("VATTaxation") Then
		VATTaxation = Parameters.VATTaxation;
	Else
		VATTaxation = Undefined;
	EndIf;
	
	If Parameters.Property("AmountIncludesVAT") Then
		AmountIncludesVAT		= Parameters.AmountIncludesVAT;
		UsingVAT 		= True;
		DocumentOrganization	= Parameters.DocumentOrganization;
	Else
		UsingVAT 		= False;
	EndIf;
	
	If Parameters.Property("ProductsAndServicesType") Then
		If ValueIsFilled(Parameters.ProductsAndServicesType)  Then
			ProductsAndServicesType = Parameters.ProductsAndServicesType;
			
			ArrayProductsAndServicesType = New Array();
			For Each ItemProductsAndServicesType IN ProductsAndServicesType Do
				If Parameters.Property("ExcludeProductsAndServicesTypeWork") 
					AND ItemProductsAndServicesType.Value = Enums.ProductsAndServicesTypes.Work Then
					Continue;
				EndIf;
				ArrayProductsAndServicesType.Add(ItemProductsAndServicesType.Value);
			EndDo;
			
			ArrayRestrictionsProductsAndServicesType = New FixedArray(ArrayProductsAndServicesType);
			NewParameter = New ChoiceParameter("Filter.ProductsAndServicesType", ArrayRestrictionsProductsAndServicesType);
			NewParameter2 = New ChoiceParameter("Additionally.TypeRestriction", ArrayRestrictionsProductsAndServicesType);
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewArray.Add(NewParameter2);
			NewParameters = New FixedArray(NewArray);
			Items.FilteredInventoryProductsAndServices.ChoiceParameters = NewParameters;
		Else
			ProductsAndServicesType = Undefined;
		EndIf;
	Else
		ProductsAndServicesType = Undefined;
	EndIf;
	
	CharacteristicsUsed 	= Constants.FunctionalOptionUseCharacteristics.Get();
	BatchesUsed 			= Constants.FunctionalOptionUseBatches.Get();
	
	If Parameters.Property("Counterparty") Then
		
		Counterparty = Parameters.Counterparty;
		
	EndIf;
	
	Parameters.Property("OwnerFormUUID", OwnerFormUUID);
	
EndProcedure //OnCreateAtServer()

&AtServer
// Procedure fills the tabular section ProductsAndServices selected -
// Parameters:
// 		DocumentArray - document array by which
// 						filling happens in dependence on fill method:
//							on all documents, on one, on marked
Procedure FillProductsAndServicesList(DocumentArray)
	
	Query			= New Query;
	
	Query.Text	= 
	"SELECT
	|	TRUE AS Mark,
	|	ExpenseReportInventory.Ref AS ReceiptDocument,
	|	ExpenseReportInventory.ProductsAndServices,
	|	ExpenseReportInventory.Characteristic,
	|	ExpenseReportInventory.Batch,
	|	ExpenseReportInventory.MeasurementUnit AS MeasurementUnit,
	|	ExpenseReportInventory.Quantity,
	|	ExpenseReportInventory.Price,
	|	ExpenseReportInventory.Amount,
	|	ExpenseReportInventory.VATRate,
	|	ExpenseReportInventory.VATAmount,
	|	ExpenseReportInventory.Total,
	|	ExpenseReportInventory.CustomerOrder,
	|	1 AS Factor,
	|	ExpenseReportInventory.Ref.VATTaxation AS VATTaxation,
	|	ExpenseReportInventory.Ref.AmountIncludesVAT AS AmountIncludesVAT
	|FROM
	|	Document.ExpenseReport.Inventory AS ExpenseReportInventory
	|WHERE
	|	ExpenseReportInventory.Ref IN(&DocumentArray)
	|	AND &ConditionOfProductsAndServicesFilterForExpenseReport
	|
	|UNION ALL
	|
	|SELECT
	|	TRUE,
	|	SupplierInvoiceInventory.Ref,
	|	SupplierInvoiceInventory.ProductsAndServices,
	|	SupplierInvoiceInventory.Characteristic,
	|	SupplierInvoiceInventory.Batch,
	|	SupplierInvoiceInventory.MeasurementUnit,
	|	SupplierInvoiceInventory.Quantity,
	|	SupplierInvoiceInventory.Price,
	|	SupplierInvoiceInventory.Amount,
	|	SupplierInvoiceInventory.VATRate,
	|	SupplierInvoiceInventory.VATAmount,
	|	SupplierInvoiceInventory.Total,
	|	CASE
	|		WHEN SupplierInvoiceInventory.Order REFS Document.PurchaseOrder
	|			THEN SupplierInvoiceInventory.Order.CustomerOrder
	|		ELSE VALUE(Document.CustomerOrder.EmptyRef)
	|	END,
	|	1,
	|	SupplierInvoiceInventory.Ref.VATTaxation,
	|	SupplierInvoiceInventory.Ref.AmountIncludesVAT
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|WHERE
	|	SupplierInvoiceInventory.Ref IN(&DocumentArray)
	|	AND &ConditionOfProductsAndServicesFilterForSupplierInvoice"; 
	
	Query.SetParameter("DocumentArray", DocumentArray);
	
	If FillOnlyToSpecifiedProductsAndServices Then
		
		Query.Text = StrReplace(Query.Text, "&ConditionOfProductsAndServicesFilterForExpenseReport",	"ExpenseReportInventory.ProductsAndServices IN(&ProductsAndServicesArray)");
		Query.Text = StrReplace(Query.Text, "&ConditionOfProductsAndServicesFilterForSupplierInvoice",	"SupplierInvoiceInventory.ProductsAndServices IN(&ProductsAndServicesArray)");
		Query.SetParameter("ProductsAndServicesArray", FilteredProductsAndServices.Unload());
		
	Else
		
		Query.Text = StrReplace(Query.Text, "&ConditionOfProductsAndServicesFilterForExpenseReport",	"True");
		Query.Text = StrReplace(Query.Text, "&ConditionOfProductsAndServicesFilterForSupplierInvoice",	"True");
		
	EndIf;
	
	QuerySelection = Query.Execute().Select();
	While QuerySelection.Next() Do
		
		If AddNewPositionsIntoTableFooter Then 
			
			FillPropertyValues(FilteredInventory.Add(), QuerySelection);
			
		Else
			
			Price = QuerySelection.Price;
			If QuerySelection.AmountIncludesVAT <> AmountIncludesVAT Then
				
				Price = Round(SmallBusinessServer.RecalculateAmountOnVATFlagsChange(Price, AmountIncludesVAT, QuerySelection.VATRate), 2);
				
			EndIf;
			
			SearchStructure = New Structure("ReceiptDocument, ProductsAndServices, Characteristic, Batch, MeasurementUnit, VATRate, Price",
				QuerySelection.ReceiptDocument,
				QuerySelection.ProductsAndServices,
				QuerySelection.Characteristic,
				QuerySelection.Batch,
				QuerySelection.MeasurementUnit,
				QuerySelection.VATRate,
				Price); //Price should coincide otherwise two rows and let define the desired price for distribution shares
				
			DuplicateRow	= FilteredInventory.FindRows(SearchStructure);
			
			//User can create by hands double. we
			//won't stir a row because it doesn't lead
			//to the wrong actions just add data in first founded row
			If DuplicateRow.Count() > 0 Then 
				
				//Calculation on the server without leaving on the client
				DuplicateRow[0].Quantity = DuplicateRow[0].Quantity + QuerySelection.Quantity;
				
				If QuerySelection.AmountIncludesVAT = AmountIncludesVAT Then
					
					DuplicateRow[0].Amount = DuplicateRow[0].Quantity * DuplicateRow[0].Price;
					
				ElsIf QuerySelection.AmountIncludesVAT AND Not AmountIncludesVAT Then
					
					DuplicateRow[0].Amount = DuplicateRow[0].Amount + Round((QuerySelection.Amount / ((QuerySelection.VATRate.Rate + 100) / 100)), 2);
					
				ElsIf QuerySelection.AmountIncludesVAT AND Not AmountIncludesVAT Then
					
					DuplicateRow[0].Amount = DuplicateRow[0].Amount + Round((QuerySelection.Amount - QuerySelection.Amount / ((QuerySelection.VATRate.Rate + 100) / 100)), 2);
					
				EndIf;
				
				DuplicateRow[0].VATAmount = DuplicateRow[0].VATAmount + QuerySelection.VATAmount;
				DuplicateRow[0].Total = DuplicateRow[0].Total + QuerySelection.Total;
				
			Else
				
				// New row
				NewRow = FilteredInventory.Add();
				FillPropertyValues(NewRow, QuerySelection, "ReceiptDocument, ProductsAndServices, Characteristic, Batch, MeasurementUnit, Amount, VATRate");
				
				NewRow.Mark = True;
				If QuerySelection.AmountIncludesVAT = AmountIncludesVAT Then
					
					NewRow.Price		= Price;
					NewRow.Amount		= QuerySelection.Amount;
					NewRow.VATAmount	= QuerySelection.VATAmount;
					NewRow.Total		= QuerySelection.Total;
					
				ElsIf QuerySelection.AmountIncludesVAT AND Not AmountIncludesVAT Then
					
					NewRow.Price		= Price;
					NewRow.Amount		= Round(QuerySelection.Amount / ((QuerySelection.VATRate.Rate + 100) / 100), 2);
					NewRow.VATAmount	= QuerySelection.VATAmount;
					NewRow.Total		= QuerySelection.Total;
					
				ElsIf Not QuerySelection.AmountIncludesVAT AND AmountIncludesVAT Then
					
					NewRow.Price		= Price;
					NewRow.Amount		= Round(QuerySelection.Amount + (QuerySelection.Amount * QuerySelection.ProductsAndServices.VATRate.Rate / 100), 2);
					NewRow.VATAmount	= QuerySelection.VATAmount;
					NewRow.Total		= QuerySelection.Total;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure //FillProductsAndServicesList()

&AtClient
//Procedure selection data processor by the Add command
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Not TypeOf(ValueSelected) = Type("Array") Then
		
		ArrayOfSelectedDocuments	= New Array;
		ArrayOfSelectedDocuments.Add(ValueSelected);
		
	Else
		
		ArrayOfSelectedDocuments	= ValueSelected;
		
	EndIf;
	
	
	For Each ReceiptDocument IN ArrayOfSelectedDocuments Do
		
		ArrayOfFoundDocuments = FilteredDocuments.FindRows(New Structure("ReceiptDocument", ReceiptDocument));
		
		If ArrayOfFoundDocuments.Count() > 0 Then
			
			MessageText = NStr("en = 'Document %DocumentPerformance% is already present in the list of selected documents.'");
			MessageText = StrReplace(MessageText, "%DocumentPerformance%", ReceiptDocument);
			
			CommonUseClientServer.MessageToUser(MessageText);
			
			Continue;
			
		EndIf;
		
		NewRow 					= FilteredDocuments.Add();
		NewRow.Mark 			= True;
		NewRow.ReceiptDocument	= ReceiptDocument;
		
	EndDo;
	
EndProcedure //ChoiceProcessing()

&AtClient
//Procedure changes the visible of rows in the table field Filtered ProductsAndServices
//
Procedure SetVisibleOfFilteredInventory(CurrentData)
	
	If CurrentData = Undefined 
		OR Not ShowProductsAndServicesForCurrentDocumentOnly Then
		
		Items.FilteredInventory.RowFilter = New FixedStructure();
		Items.FilteredInventory.Refresh();
		
	Else
		
		Items.FilteredInventory.RowFilter = New FixedStructure("ReceiptDocument", CurrentData.ReceiptDocument);
		
	EndIf;

EndProcedure //SetFilteredInventoryVisible()

&AtClient
// Procedure of opening multiple selection by documents
//
Procedure DocumentsMultiplePick(Command)
	
	// 1. Here define the type
	// of added document 2. Open list for selection
	
	ListOfDocumentTypes = New ValueList();
	ListOfDocumentTypes.Add("ExpenseReport", "Expense report");
	ListOfDocumentTypes.Add("SupplierInvoice", "Supplier invoice");
	
	Notification = New NotifyDescription("MultiplePickupDocumentsCompletion",ThisForm);
	ListOfDocumentTypes.ShowChooseItem(Notification, "Select the document type for add");
	
	Cancel = True;
	
EndProcedure //MultipleDocumentsPick()

&AtClient
Procedure MultiplePickupDocumentsCompletion(SelectItem,Parameters) Export
	
	If Not SelectItem = Undefined Then 
		
		ChoiceParameters = New Structure;
		ChoiceParameters.Insert("Multiselect", True);
		
		If Not AccountingBySubsidiaryCompany Then
			
			ChoiceParameters.Insert("Filter", New Structure("Company", DocumentOrganization));
			
		EndIf;
		
		OpenForm("Document." + SelectItem.Value + ".ChoiceForm", ChoiceParameters, ThisForm);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM BUTTONS EVENTS HANDLERS

&AtClient
//Procedure event handler of
// enable/disable the options Show ProductsAndServices Only For CurrentDocument
//
Procedure ShowProductsAndServicesForCurrentDocumentOnlyOnChange(Item)
	
	SetVisibleOfFilteredInventory(Items.FilteredDocuments.CurrentData);

EndProcedure //ShowProductsAndServicesForCurrentDocumentOnlyOnChange()

&AtClient
//Procedure - OK button click handler.
//
Procedure OK(Command)
	
	InventoryAddressInStorage = WritePickToStorage();
	
	SelectionParameters = New Structure;
	SelectionParameters.Insert("InventoryAddressInStorage", InventoryAddressInStorage);
	SelectionParameters.Insert("AddNewPositionsIntoTableFooter", AddNewPositionsIntoTableFooter);
	
	Notify("PickupOnDocumentsProduced", SelectionParameters, OwnerFormUUID);
	
	Close();
	
EndProcedure //Ok()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABLE PARTS ATTRIBUTE EVENT HANDLERS

&AtClient
// Procedure fills the document array
// by marked and sends it in fill procedure
// of the table field Filtered inventories
Procedure FillByFilteredDocuments(Command)
	
	If FilteredInventory.Count() > 0 Then
		
		QuestionText = NStr("en = 'Table part will be cleared and filled repeated. Continue?'");
		
		Response = Undefined;
		
		
		ShowQueryBox(New NotifyDescription("FillByFilteredDocumentsEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, 0);
		Return;
		
	EndIf;
	
	FillByFilteredDocumentsFragment();
	
EndProcedure

&AtClient
Procedure FillByFilteredDocumentsEnd(Result, AdditionalParameters) Export
    
    Response = Result; 
    
    If Not Response = DialogReturnCode.Yes Then
        
        Return;
        
    EndIf;
    
    
    FillByFilteredDocumentsFragment();

EndProcedure

&AtClient
Procedure FillByFilteredDocumentsFragment()
	Var DocumentArray, ReceiptDocumentRow;
	
	FilteredInventory.Clear();
	
	DocumentArray = New Array;
	For Each ReceiptDocumentRow IN FilteredDocuments Do
		
		If Not ReceiptDocumentRow.Mark Then
			
			Continue;
			
		EndIf;
		
		DocumentArray.Add(ReceiptDocumentRow.ReceiptDocument);
		
	EndDo;
	
	FillProductsAndServicesList(DocumentArray);
	
EndProcedure //FillByFilteredDocuments()

&AtClient
// Procedure fills the document array
// by current document regardless of a mark and passes
// the array in the table
// field fill procedure Filtered inventories
Procedure FillByCurrentDocument(Command)
	
	CurrentRowOfReceiptDocuments	= Items.FilteredDocuments.CurrentData;
	
	If CurrentRowOfReceiptDocuments = Undefined Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Choose row with a document and retry to fill again'"),
			,
			"FilteredDocuments",
			,
			);
			
		Return;
		
	EndIf;
	
	DocumentArray = New Array;
	DocumentArray.Add(CurrentRowOfReceiptDocuments.ReceiptDocument);
	
	FillProductsAndServicesList(DocumentArray);
	
EndProcedure //FillByCurrentDocument()

&AtClient
//Procedure clears the table field Filtered inventories
//
Procedure ClearFilteredInventory(Command)
	
	FilteredInventory.Clear();
	
EndProcedure //ClearFilteredInventory()

&AtClient
// Procedure of document add in
// the list of selected document values
//
Procedure DocumentsListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	// 1. Here define the type
	// of added document 2. Open list for selection
	
	ListOfDocumentTypes = New ValueList();
	ListOfDocumentTypes.Add("ExpenseReport", "Expense report");
	ListOfDocumentTypes.Add("SupplierInvoice", "Supplier invoice");
	
	Notification = New NotifyDescription("DocumentsListBeforeAddCompletion",ThisForm);
	ListOfDocumentTypes.ShowChooseItem(Notification,"Select the document type for add");
	
	Cancel = True;
	
EndProcedure //DocumentListBeforeAddStart()

&AtClient
Procedure DocumentsListBeforeAddCompletion(SelectItem,Parameters) Export
	
	If Not SelectItem = Undefined Then
		
		ChoiceParameters = New Structure;
		
		If Not AccountingBySubsidiaryCompany Then
			
			ChoiceParameters.Insert("Filter", New Structure("Company", DocumentOrganization));
			
		EndIf;
		
		OpenForm("Document." + SelectItem.Value + ".ChoiceForm", ChoiceParameters, ThisForm);
		
	EndIf;
	
EndProcedure

&AtClient
// VAT amount is calculated in the row of tabular section.
//
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(
		AmountIncludesVAT,
		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
		TabularSectionRow.Amount * VATRate / 100);
	
EndProcedure // CalculateVATAmount()

&AtClient
// Procedure calculates the amount in the row of tabular section.
//
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.FilteredInventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure // CalculateAmountInTabularSectionLine()

&AtClient
//Procedure calculates the amount
//by row in dependence on assigned amount
Procedure FilteredInventoryCountOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure //FilteredInventoryCountOnChange()

&AtClient
//Procedure calculates the amount
//by row in dependence on determined price
Procedure FilteredInventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure //FilteredInventoryPriceOnChange()

&AtClient
//Procedure calculates the price
//by row in dependence on determined amount
Procedure FilteredInventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.FilteredInventory.CurrentData;
	
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(AmountIncludesVAT, 0, TabularSectionRow.VATAmount);

EndProcedure //FilteredInventoryAmountOnChange()

&AtClient
//Procedure recalculates the VAT
//amount in dependence on the modified VAT rate
Procedure FilteredInventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.FilteredInventory.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(AmountIncludesVAT, 0, TabularSectionRow.VATAmount);

EndProcedure //FilteredInventoryVATRateOnChange()

&AtClient
//Procedure calculates the total
//amount in dependence on changed VAT amount
Procedure FilteredInventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.FilteredInventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(AmountIncludesVAT, 0, TabularSectionRow.VATAmount);

EndProcedure //FilteredInventoryVATAmountOnChange()

&AtClient
//Procedure of event handler of row activization in the list of the filtered documents
//
Procedure FilteredDocumentsOnActivateRow(Item)
	
	SetVisibleOfFilteredInventory(Items.FilteredDocuments.CurrentData);
	
EndProcedure //FilteredDocumentsOnActivateRow()

&AtClient
//Procedure of set checkbox in
//the all rows of table field Filtered inventories
//
Procedure MarkAllPositions(Command)
	
	For Each Row IN FilteredInventory Do
		
		Row.Mark = True;
		
	EndDo;
	
EndProcedure //MarkAllPositions()

&AtClient
//Procedure of checkbox clear
//with all rows of table field Filtered inventories
//
Procedure UnmarkAllPositions(Command)
	
	For Each Row IN FilteredInventory Do
		
		Row.Mark = False;
		
	EndDo;
	
EndProcedure //DisableAllocationFromAllPositions()

&AtClient
// Procedure - event handler SelectionDataProcessor table field FilteredDocuments
//
Procedure FilteredDocumentsChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing 	= False;
	
	For Each ArrayElement IN ValueSelected Do
		
		SearchStructure = New Structure("ReceiptDocument", ArrayElement);
		
		FoundStringArray = FilteredDocuments.FindRows(SearchStructure);
		
		If FoundStringArray.Count() < 1 Then 
			
			FilteredDocuments.Add(ArrayElement, , True);
			
		EndIf;
		
	EndDo;
	
EndProcedure //FilteredDocumentsChoiceProcessing()

&AtClient
// Procedure - events handler "Selection" of table field "SelectedInventory"
//
Procedure FilteredInventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentRowOfTabularSection = Items.FilteredInventory.CurrentData;
	
	If Not CurrentRowOfTabularSection = Undefined Then
		
		If TypeOf(CurrentRowOfTabularSection.ReceiptDocument) = Type("DocumentRef.SupplierInvoice") Then
			
			OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("Key", CurrentRowOfTabularSection.ReceiptDocument));
			
		ElsIf TypeOf(CurrentRowOfTabularSection.ReceiptDocument) = Type("DocumentRef.ExpenseReport") Then
			
			OpenForm("Document.ExpenseReport.ObjectForm", New Structure("Key", CurrentRowOfTabularSection.ReceiptDocument));
			
		EndIf;
		
	EndIf;
	
EndProcedure //FilteredInventorySelection()
