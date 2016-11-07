////////////////////////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("DocumentKinds") Then
		DocumentKinds = Parameters.DocumentKinds;
	Else
		DocumentKinds = New Array;
	EndIf;
	
	GenerateTreeSpeciesDocuments(DocumentKinds);
	Items.DocumentTypesFilter.InitialTreeView = InitialTreeView.ExpandAllLevels;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////
// TABLE EVENT HANDLERS FilterByDocumentKinds FORMS

&AtServer
Procedure AddLineTreeOfDocumentsKind(MetadataObject, UpperLevelRow)

	StringDetails = UpperLevelRow.Rows.Add();
	StringDetails.MetadataObjectName = MetadataObject.Name;
	StringDetails.FullMetadataName = MetadataObject.FullName();
	StringDetails.Presentation = MetadataObject.Synonym;

EndProcedure

&AtServer
Procedure GenerateTreeSpeciesDocuments(ArraySelectedValues)

	FilterTree = FormAttributeToValue("FilterByDocumentKindsTree", Type("ValueTree"));
	FilterTree.Rows.Clear();
	
	MetaDocuments = Metadata.Documents;
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Sales";
	
	AddLineTreeOfDocumentsKind(MetaDocuments.AcceptanceCertificate, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CustomerInvoice, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InvoiceForPayment, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CustomerInvoiceNote, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.AgentReport, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.RetailReport, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.RetailRevaluation, UpperLevelRow);
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Purchases";
	
	AddLineTreeOfDocumentsKind(MetaDocuments.SupplierInvoice, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.AdditionalCosts, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.ReportToPrincipal, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.SubcontractorReport, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryTransfer, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryReconciliation, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryReceipt, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryWriteOff, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.SupplierInvoiceNote, UpperLevelRow);
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Service";
	
	StringDetails = UpperLevelRow.Rows.Add();
	StringDetails.MetadataObjectName = MetaDocuments.CustomerOrder.Name;
	StringDetails.FullMetadataName = MetaDocuments.CustomerOrder.FullName();
	StringDetails.Presentation = "Job-order";
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Production";
	
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryAssembly, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.InventoryTransfer, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.ProcessingReport, UpperLevelRow);
	
	UpperLevelRow = FilterTree.Rows.Add();
	UpperLevelRow.Presentation = "Funds";
	
	AddLineTreeOfDocumentsKind(MetaDocuments.ExpenseReport, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CashReceipt, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.PaymentReceipt, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CashPayment, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.PaymentExpense, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.CashTransfer, UpperLevelRow);
	AddLineTreeOfDocumentsKind(MetaDocuments.PaymentOrder, UpperLevelRow);
	
	For Each UpperLevelRow IN FilterTree.Rows Do
		AllItemsAreSelected = True;
		For Each StringDetails IN UpperLevelRow.Rows Do
			If ArraySelectedValues.Find(StringDetails.MetadataObjectName) = Undefined Then
				AllItemsAreSelected = False;
			Else
				StringDetails.Check = True;
			EndIf;
			StringDetails.PictureIndex = -1;
		EndDo;
		If AllItemsAreSelected Then
			UpperLevelRow.Check = True;
		EndIf;
		UpperLevelRow.PictureIndex = 0;
	EndDo;
	
	ValueToFormAttribute(FilterTree, "FilterByDocumentKindsTree");
	
EndProcedure

&AtClient
Procedure Unmark(Command)
	
	FillMarks(False);
	
EndProcedure

&AtClient
Procedure MarkAll(Command)
	
	FillMarks(True);
	
EndProcedure

&AtServer
Procedure FillMarks(MarkValue, ItemIdentificator = Undefined)
	If ItemIdentificator <> Undefined Then
		TreeItem = FilterByDocumentKindsTree.FindByID(ItemIdentificator);
		LowerLevelElements = TreeItem.GetItems();
		For Each LowerLevelElement IN LowerLevelElements Do
			LowerLevelElement.Check = MarkValue;
		EndDo;
	Else
		UpperLevelItems = FilterByDocumentKindsTree.GetItems();
		For Each TopLevelItem IN UpperLevelItems Do
			TopLevelItem.Check = MarkValue;
			LowerLevelElements = TopLevelItem.GetItems();
			For Each LowerLevelElement IN LowerLevelElements Do
				LowerLevelElement.Check = MarkValue;
			EndDo;
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure DocumentTypesFilterCheckOnChange(Item)
	
	CurrentData = Items.DocumentTypesFilter.CurrentData;
	If CurrentData <> Undefined Then
		
		MarkValue = CurrentData.Check;
		If CurrentData.GetParent() = Undefined Then
			FillMarks(MarkValue, CurrentData.GetID());
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteClose(Command)
	
	CloseParametersForms = New Structure();
	CloseParametersForms.Insert("AddressTableInTemporaryStorage", GenerateTableSelectedValues());
	CloseParametersForms.Insert("TableNameForFill",          "DocumentKinds");
	
	NotifyChoice(CloseParametersForms);
	
EndProcedure

&AtServer
Function GenerateTableSelectedValues()

	TableSelectedValues = New ValueTable;
	TableSelectedValues.Columns.Add("MetadataObjectName");
	TableSelectedValues.Columns.Add("Presentation");
	
	UpperLevelItems = FilterByDocumentKindsTree.GetItems();
	For Each TopLevelItem IN UpperLevelItems Do
		ItemsDetailedRecords = TopLevelItem.GetItems();
		For Each DetailedRecordsItem IN ItemsDetailedRecords Do
			If Not DetailedRecordsItem.Check Then
				Continue;
			EndIf;
			NewRow = TableSelectedValues.Add();
			NewRow.MetadataObjectName = DetailedRecordsItem.MetadataObjectName;
			NewRow.Presentation = DetailedRecordsItem.Presentation;
		EndDo;
	EndDo;
	
	Return PutToTempStorage(TableSelectedValues, UUID);

EndFunction






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
