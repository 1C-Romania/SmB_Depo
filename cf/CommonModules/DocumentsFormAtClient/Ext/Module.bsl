
Function GetMainForm(Form)
	If TypeOf(Form) = Type("ManagedForm") Then
		Return Form;
	ElsIf Form = Undefined Then
		Return Undefined;
	Else
		Return GetMainForm(Form.Parent);
	EndIf;
EndFunction

Function TabularPartCleaning(TabularPart, ClearTabularPart = True) Export 
	
	If TabularPart.Count() > 0 Then
		
		Answer = DoQueryBox(NStr("en='Tabular part would be cleaned up. Existing rows would be deleted. Continue?';pl='Część tabelaryczna zostanie wyczyszczona. Istniejące wiersze zostaną skasowane. Czy kontynuować?'"), QuestionDialogMode.OKCancel);
		If Answer <> DialogReturnCode.OK Then
			Return False;
		EndIf;
		If ClearTabularPart Then
			TabularPart.Clear();
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

Function TabularPartCanBeFilled(TabularPart, Posted, ClearTabularPart = True) Export 
	
	If Posted Then
		ShowMessageBox(, NStr("en='Please, clear posting of the document before filling.';pl='Odksięguj dokument przed rozpoczęciem jego wypełniania.'"));
		Return False;
	EndIf;
	
	If Not TabularPartCleaning(TabularPart, ClearTabularPart) Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Procedure TabularPartFillingRequest(NotifyDescriptionOnProceed,Val TabularPartLinesCount, Val ShowUnpostMessage = False, AdditionalParameters = Undefined) Export 
	
	If ShowUnpostMessage Then
		ShowMessageBox(, NStr("en='Please, clear posting of the document before filling.';pl='Anuluj zatwierdzenie dokumentu przed rozpoczęciem jego wypełniania.';ru='Перед началом заполнения документа отмените его проведение.'"));	
		Return;
	EndIf;	
	
	If TabularPartLinesCount > 0 Then
		
		QueryText	= NStr("en='Tabular part would be cleaned up. Existing rows would be deleted. Continue?';
							|pl='Część tabelaryczna zostanie wyczyszczona. Istniejące wiersze zostaną skasowane. Czy kontynuować?'");
		QueryMode	= QuestionDialogMode.OKCancel;
		Notify		= New NotifyDescription("TabularPartFillingResponse", DocumentsFormAtClient, New Structure("NotifyDescriptionOnProceed", NotifyDescriptionOnProceed));
		ShowQueryBox(Notify, QueryText, QueryMode);
		
	Else
		
		ExecuteNotifyProcessing(NotifyDescriptionOnProceed);
		
	EndIf;
	
EndProcedure

Procedure TabularPartFillingResponse(Answer, Parameters) Export 
	
	If Answer <> DialogReturnCode.OK Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.NotifyDescriptionOnProceed);
	
EndProcedure

Function AfterWrite(Form) Export
	
	If Form.Items.Find("NumberPreview") <> Undefined Then
		Form.ShowNumberPreview = False;
		UpdateDialog(Form);
	EndIf;
	
EndFunction	

Procedure UpdateDialog(Form) Export
	If Not Form.Items.Find("ItemsLinesReservedQuantity") = Undefined Then
		If TypeOf(Form.Object.Ref) = Type("DocumentRef.SalesDelivery") Then
			Form.Items.ItemsLinesReservedQuantity.Visible = Form.Object.OperationType = PredefinedValue("Enum.OperationTypesSalesDelivery.SalesInvoice");
		ElsIf TypeOf(Form.Object.Ref) = Type("DocumentRef.SalesOrder") Then
			Form.Items.ItemsLinesReservedQuantity.Visible = (Form.Object.ReservationMode = PredefinedValue("Enum.SalesOrderReservationMode.DefineManually"));	
		EndIf;
	EndIf;
	If Not Form.Items.Find("ItemsLinesVAT") = Undefined Then
		VATCalculationMethod = DocumentsPostingAndNumbering.GetVATCalculationMethod(Form.Object.Date, Form.Object.Company);
		Form.Items.ItemsLinesVAT.ReadOnly = Not (VATCalculationMethod = PredefinedValue("Enum.VATCalculationMethod.ByEachDocumentLine"));
	EndIf;
	
	If Not Form.Items.Find("FixedAssetsLinesVAT") = Undefined Then
		VATCalculationMethod = DocumentsPostingAndNumbering.GetVATCalculationMethod(Form.Object.Date, Form.Object.Company);
		Form.Items.FixedAssetsLinesVAT.ReadOnly = Not (VATCalculationMethod = PredefinedValue("Enum.VATCalculationMethod.ByEachDocumentLine"));
	EndIf;
	
	If Not Form.Items.Find("CommonCommandVATTable") = Undefined Then
		Form.Items.CommonCommandVATTable.Title = NStr("en='VAT :';pl='VAT :'"); 
		If Form.Items.Find("VATLinesTotalVAT") = Undefined Then
			Form.Items.CommonCommandVATTable.Title = Form.Items.CommonCommandVATTable.Title + FormatAmount(Form.Object.VATLines.Total("VAT"), Form.Object.Currency,,,False);
		EndIf;
	EndIf;
	
	If Not Form.Items.Find("SettingDocumentsNumbers") = Undefined Then
		Form.Items.SettingDocumentsNumbers.Visible = Form.Object.Ref.isEmpty();			
	EndIf;
	
	If Not Form.Items.Find("Number") = Undefined Then
		Form.Items.Number.Visible = NOT Form.ShowNumberPreview;			
	EndIf;
	
	If Not Form.Items.Find("NumberPreview") = Undefined Then
		Form.Items.GroupNumberPreview.CurrentPage = ?(Form.ShowNumberPreview, Form.Items.PageNumberPreview, Form.Items.PageNumber);
	EndIf;
	
	If Not Form.Items.Find("SetNewNumber") = Undefined Then
		Form.Items.SetNewNumber.Visible = Form.Object.Ref.isEmpty();			
	EndIf;
	
	If Not Form.Items.Find("SetNewPrefix") = Undefined Then
		Form.Items.SetNewPrefix.Visible = Form.Object.Ref.isEmpty();			
	EndIf;
	
EndProcedure

Procedure OnOpen(Form, Cancel) Export
	If Not Form.Items.Find("LabelPriceAndDiscountSettings") = Undefined Then
		DocumentsFormAtClient.SetPriceAndDiscountLabelText(Form);
	EndIf;
	If Not Form.Items.Find("Settlements") = Undefined Then
		Partner = Undefined;
		If Not Form.Items.Find("Customer") = Undefined Then
			Partner = Form.Object.Customer;
		EndIf;
		For Each RowSettlement In Form.Settlements Do
			RowSettlement.SettlementInfo = GetDescriptionSettlement(RowSettlement, Partner);
		EndDo;
	EndIf;
	
	#If NOT ThickClientOrdinaryApplication Then
		MainFormOwner = Form.FormOwner;
		MainFormOwner = GetMainForm(MainFormOwner);
	#Else
		MainFormOwner = Undefined;
	#EndIf

	Form.FormOwnerUUID = ?(MainFormOwner = Undefined, "", MainFormOwner.UUID);
	Form.UpdateDialog();
	If Form.Object.Ref.IsEmpty() Then
		Form.Modified = True;
	EndIf;
	HeaderValue = New Structure(Form.HeaderValue);
	HeaderValue.Date = Form.Object.Date;
	Form.HeaderValue = New FixedStructure(HeaderValue);
EndProcedure

Procedure ListOnOpen(Form, Cancel) Export
	SetCommandsInterface(Form, Cancel, New Structure("Type", "LIST")); 
EndProcedure

Procedure GetBasePriceAndDiscountValue(Form, AttributeStructure)
	For Each AttributeInfo In AttributeStructure Do
		AttributeValue = Undefined;
		IsAttributeInObject = Form.Object.Property(AttributeInfo.Key, AttributeValue);
		If IsAttributeInObject Then
			AttributeStructure[AttributeInfo.Key] = AttributeValue;
		EndIf;
	EndDo;
EndProcedure

Procedure SetPriceAndDiscountLabelText(Form, DocumentInfoStructure = Undefined) Export
	
	If DocumentInfoStructure = Undefined Then
		PriceType = Undefined;
		IsPriceType = Form.Object.Property("PriceType", PriceType);
		If IsPriceType And PriceType = Undefined Then
			PriceType = Form.PriceType;
		EndIf;
		
		AttributeStructure = New Structure("Currency, ExchangeRate,DiscountGroup,PriceType,AmountType");
		GetBasePriceAndDiscountValue(Form, AttributeStructure);
		
		ShowCurrency = Not AttributeStructure.Currency = Undefined;
		ShowDiscountGroup = Not AttributeStructure.DiscountGroup = Undefined;
		ShowPriceType = Not AttributeStructure.PriceType = Undefined;
		ShowAmountType = Not AttributeStructure.AmountType = Undefined;
		//ShowNBPTable = Not AttributeStructure. = Undefined;
		
		LabelsStructure = PricesAndDiscountsAtClient.GetLabelsStructureForPriceAndDiscountAttributes(AttributeStructure, ShowCurrency, ShowDiscountGroup, ShowPriceType, ShowAmountType);
	Else
		LabelsStructure = PricesAndDiscountsAtClient.GetLabelsStructureForPriceAndDiscountAttributes(DocumentInfoStructure);
	EndIf;
	Form.Items.LabelPriceAndDiscountSettings.Title = LabelsStructure.LabelText; 
	
EndProcedure	

Procedure ChangeDocumentsHeader(Form, Val MainParameters, Val AdditionalParameters) Export
	If MainParameters = Undefined Then
		Form.Modified = AdditionalParameters.Modified;
		FillPropertyValues(Form.Object, AdditionalParameters);
	Else
		
		FillPropertyValues(Form.Object, MainParameters);
		Form.Modified = True;
		Form.ChangeDocumentsHeaderAtServer(Not MainParameters.Date = AdditionalParameters.Date);
		
		Form.UpdateDialog();
	EndIf;
EndProcedure

Procedure ExchangeRateChoiceProcessing(Form, Item, SelectedValue, StandardProcessing, Currency = Undefined) Export
	
	StandardProcessing = False;
	
	If SelectedValue = Undefined Then
		ListFormParameters = New Structure;
		If Currency = Undefined Then
			ListFormParameters.Insert("Filter",New Structure("Currency", Form.BankAccountCurrency));
		Else
			ListFormParameters.Insert("Filter",New Structure("Currency", Currency));
		EndIf;
		ListFormParameters.Insert("ReturnRow", Undefined);
		ListFormParameters.Insert("ChoiceMode",True);
		ListFormParameters.Insert("CloseOnChoice",True);
		OpenForm("InformationRegister.CurrencyExchangeRates.ListForm", ListFormParameters, Item);		
		Return;
	ElsIf TypeOf(SelectedValue) = Type("Number") Then
		Form.Object[Item.Name] = SelectedValue;
		Return;
	EndIf;
	
	Form.Object[Item.Name] = SelectedValue.ExchangeRate;

EndProcedure

Function GetDescriptionSettlement(RowSettlement, DocumentPartner = Undefined) Export
	ResultText = "";
	
	StructureDescription = New Structure("Type, Partner, PaymentMethod, BankCash, Document, PrepaymentInvoice, ReservationDocument, VATRate");
	
	If RowSettlement.Type = "Payments" Then
		StructureDescription.Type = NStr("en='Payment';pl='Zapłata'");
	ElsIf RowSettlement.Type = "Prepayments" Then
		StructureDescription.Type = NStr("en='Prepayment';pl='Zaliczka';ru='Аванс'");
	ElsIf RowSettlement.Type = "PrepaymentInvoiceVATLines" Then
		StructureDescription.Type = NStr("en='Prepayment invoice';pl='Faktura zaliczkowa';ru='Фактура на аванс'");
	EndIf;
	
	If Not RowSettlement.Partner = DocumentPartner Then
		StructureDescription.Partner = String(RowSettlement.Partner);
	EndIf;
	If ValueIsFilled(RowSettlement.PaymentMethod) Then
		StructureDescription.PaymentMethod = String(RowSettlement.PaymentMethod);
	EndIf;
	If ValueIsFilled(RowSettlement.BankCash) Then
		StructureDescription.BankCash = String(RowSettlement.BankCash);
	EndIf;
	
	If ValueIsFilled(RowSettlement.PrepaymentInvoice) Then
		StructureDescription.PrepaymentInvoice = String(RowSettlement.PrepaymentInvoice);
	ElsIf ValueIsFilled(RowSettlement.Document) Then
		StructureDescription.Document = String(RowSettlement.Document);
	EndIf;
	If ValueIsFilled(RowSettlement.ReservationDocument) Then
		StructureDescription.ReservationDocument = String(RowSettlement.ReservationDocument);
	EndIf;
	If ValueIsFilled(RowSettlement.VATRate) Then
		StructureDescription.VATRate = String(RowSettlement.VATRate);
	EndIf;
	
	ResultText = StructureDescription.Type + ": ";
	
	If ValueIsFilled(StructureDescription.PaymentMethod) Then
		ResultText = ResultText + StructureDescription.PaymentMethod + "; ";
	EndIf;
	If ValueIsFilled(StructureDescription.BankCash) Then
		ResultText = ResultText + StructureDescription.BankCash + "; ";
	EndIf;

	If ValueIsFilled(StructureDescription.Partner) Then
		ResultText = ResultText + StructureDescription.Partner + "; ";
	EndIf;
	If ValueIsFilled(StructureDescription.PrepaymentInvoice) Then
		ResultText = ResultText + StructureDescription.PrepaymentInvoice;
	ElsIf ValueIsFilled(StructureDescription.Document) Then
		ResultText = ResultText + StructureDescription.Document;
	EndIf;
	If ValueIsFilled(StructureDescription.ReservationDocument) Then
		ResultText = ResultText + "; " + StructureDescription.ReservationDocument;
	EndIf;
	If ValueIsFilled(StructureDescription.VATRate) Then
		ResultText = ResultText + "; VAT:" + StructureDescription.VATRate + ": " + Format(RowSettlement.VAT, "NFD=2");
	EndIf;

	Return ResultText;
EndFunction

Function GetSettlementsLineParameters(Form, CurrentSettlements, DocumentType, IsNew) Export 

	FormParameters = New Structure;
	
	TableStructure = New Structure;
	If Not DocumentType = "PurchaseOrder" AND  Not DocumentType = "PurchaseInvoice" Then
		TableStructure.Insert("Payments");
	EndIf;
	If NOT DocumentType = "SalesRetailReturn"
		AND NOT DocumentType = "BookkeepingNote" Then
		TableStructure.Insert("Prepayments");
	EndIf;

	If DocumentType = "SalesInvoice" Or DocumentType = "SalesRetail" Or DocumentType = "SalesRetail" Or DocumentType = "PurchaseInvoice" Then
		TableStructure.Insert("PrepaymentInvoiceVATLines");
	EndIf;
	FormParameters.Insert("TableStructures", TableStructure);
	
	FormParameters.Insert("Company", Form.Object.Company);
	FormParameters.Insert("SettlementCurrency", Form.Object.Currency);
	If Not Form.Items.Find("Customer") = Undefined Then
		FormParameters.Insert("Partner", ?(ValueIsFilled(CurrentSettlements.Partner), CurrentSettlements.Partner, Form.Object.Customer));
	ElsIf Not Form.Items.Find("Supplier") = Undefined Then
		FormParameters.Insert("Partner", ?(ValueIsFilled(CurrentSettlements.Partner), CurrentSettlements.Partner, Form.Object.Supplier));
	Else
		FormParameters.Insert("Partner", Undefined);
	EndIf;
	FormParameters.Insert("Amount", CurrentSettlements.GrossAmount);
	FormParameters.Insert("GrossAmount", CurrentSettlements.GrossAmount);
	FormParameters.Insert("NetAmount", CurrentSettlements.NetAmount);
	FormParameters.Insert("VAT", CurrentSettlements.VAT);
	FormParameters.Insert("VATRate", CurrentSettlements.VATRate);
	FormParameters.Insert("Document", CurrentSettlements.Document);
	FormParameters.Insert("PrepaymentInvoice", CurrentSettlements.PrepaymentInvoice);
	FormParameters.Insert("ReservationDocument", CurrentSettlements.ReservationDocument);
	FormParameters.Insert("Type", CurrentSettlements.Type);
	FormParameters.Insert("BankCash", CurrentSettlements.BankCash);
	FormParameters.Insert("PaymentMethod", CurrentSettlements.PaymentMethod);
	FormParameters.Insert("DocumentType", DocumentType);		
	
	Return FormParameters;
EndFunction

Procedure OpenDocumentsSettlementsForm(Form, DocumentType = Undefined) Export
	If DocumentType = Undefined Then
		DocumentType = Form.ObjectMetadataName;
	EndIf;
	CurrentSettlements = Form.Items.Settlements.CurrentData;
	If CurrentSettlements.Partner = Undefined Then
		If Form.ObjectMetadataName = "PurchaseOrder" OR Form.ObjectMetadataName = "PurchaseInvoice" Then
			CurrentSettlements.Partner = Form.Object.Supplier;
		Else
			
		EndIf;
	EndIf;
	
	FormParameters = DocumentsFormAtClient.GetSettlementsLineParameters(Form, CurrentSettlements, DocumentType, Not ValueIsFilled(CurrentSettlements.Type));
	
	Notify = New NotifyDescription(
		"ChangeDocumentSettlements",
		Form, 
		New Structure("CurrentSettlements", CurrentSettlements));

	OpenForm("CommonForm.DocumentsSettlements", FormParameters, ,,,, Notify, FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

Procedure ChangeDocumentSettlements(Form, MainParameters, AdditionalParameters) Export
	CurrentSettlements = AdditionalParameters.CurrentSettlements;

	FillPropertyValues(CurrentSettlements, MainParameters);

	CurrentSettlements.GrossAmount = MainParameters.Amount;
	CurrentSettlements.SettlementInfo = GetDescriptionSettlement(CurrentSettlements, ?(Form.Items.Find("Customer") = Undefined , Form.Object.Supplier, Form.Object.Customer));
	Form.Modified = True;
EndProcedure

Procedure SetFilterSettlementsChoiceList(Form, FilterValue) Export 
	For Each UserSettingsItem In Form.SettlementsChoiceList.SettingsComposer.UserSettings.Items Do
		If TypeOf(UserSettingsItem) = Type("DataCompositionFilter") Then
			For Each FilterItem In UserSettingsItem.Items Do
				If FilterItem.LeftValue = New DataCompositionField("Partner") Then
					FilterItem.RightValue = FilterValue.Partner;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	Form.SettlementsChoiceList.Filter.Items.Clear();
	
	NewFilterItem = Form.SettlementsChoiceList.Filter.Items.Add(Type("DataCompositionFilterItem"));
	NewFilterItem.LeftValue = New DataCompositionField("Currency");
	NewFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	NewFilterItem.RightValue = FilterValue.Currency;
	NewFilterItem.Use = True;
	
	NewFilterItem = Form.SettlementsChoiceList.Filter.Items.Add(Type("DataCompositionFilterItem"));
	NewFilterItem.LeftValue = New DataCompositionField("Company");
	NewFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	NewFilterItem.RightValue = Form.Object.Company;
	NewFilterItem.Use = True;
	
	NewFilterItem = Form.SettlementsChoiceList.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	DocType = TypeOf(Form.Object.Ref);
	
	If DocType = Type("DocumentRef.SalesOrder")OR DocType = Type("DocumentRef.PurchaseOrder")
		OR DocType = Type("DocumentRef.PurchaseInvoice") Then
		NewFilterItem.LeftValue = New DataCompositionField("ReservationDocumentType");
		NewFilterItem.ComparisonType = DataCompositionComparisonType.InList;
		ArrayTypes = New Array;
		ArrayTypes.Add(Type("Undefined"));
		ArrayTypes.Add(Type("CatalogRef.CustomerInternalDocuments"));
		NewFilterItem.RightValue = ArrayTypes;
		NewFilterItem.Use = True;
	ElsIf DocType = Type("DocumentRef.SalesInvoice") OR DocType = Type("DocumentRef.SalesRetail") Then
		NewFilterItem.LeftValue = New DataCompositionField("ReservationDocumentType");
		NewFilterItem.ComparisonType = DataCompositionComparisonType.InList;
		ArrayTypes = New Array;
		ArrayTypes.Add(Type("Undefined"));
		ArrayTypes.Add(Type("CatalogRef.CustomerInternalDocuments"));
		ArrayTypes.Add(Type("DocumentRef.SalesOrder"));
		NewFilterItem.RightValue = ArrayTypes;
		NewFilterItem.Use = True;
	EndIf;
	If DocType = Type("DocumentRef.PurchaseOrder")OR DocType = Type("DocumentRef.PurchaseInvoice") Then
		NewFilterItem = Form.SettlementsChoiceList.Filter.Items.Add(Type("DataCompositionFilterItem"));
		NewFilterItem.LeftValue = New DataCompositionField("DocumentType");
		NewFilterItem.ComparisonType = DataCompositionComparisonType.InList;
		ArrayTypes = New Array;
		ArrayTypes.Add(Type("DocumentRef.BankOutgoingToPartner"));
		ArrayTypes.Add(Type("DocumentRef.CashOutgoingToPartner"));
		NewFilterItem.RightValue = ArrayTypes;
		NewFilterItem.Use = False;
	ElsIf DocType = Type("DocumentRef.SalesOrder") Then
		NewFilterItem = Form.SettlementsChoiceList.Filter.Items.Add(Type("DataCompositionFilterItem"));
		NewFilterItem.LeftValue = New DataCompositionField("DocumentType");
		NewFilterItem.ComparisonType = DataCompositionComparisonType.InList;
		ArrayTypes = New Array;
		ArrayTypes.Add(Type("DocumentRef.BankIncomingFromPartner"));
		ArrayTypes.Add(Type("DocumentRef.CashIncomingFromPartner"));
		NewFilterItem.RightValue = ArrayTypes;
		NewFilterItem.Use = True;
	ElsIf DocType = Type("DocumentRef.SalesInvoice") OR DocType = Type("DocumentRef.SalesRetail") Then

		NewFilterItem = Form.SettlementsChoiceList.Filter.Items.Add(Type("DataCompositionFilterItem"));
		NewFilterItem.LeftValue = New DataCompositionField("DocumentType");
		NewFilterItem.ComparisonType = DataCompositionComparisonType.InList;
		ArrayTypes = New Array;
		ArrayTypes.Add(Type("DocumentRef.BankIncomingFromPartner"));
		ArrayTypes.Add(Type("DocumentRef.CashIncomingFromPartner"));
		ArrayTypes.Add(Type("DocumentRef.SalesPrepaymentInvoice"));
		NewFilterItem.RightValue = ArrayTypes;
		NewFilterItem.Use = True;
		
	EndIf;

	For Each RowSettlements In Form.Settlements Do
		NewFilterGroupItem = Form.SettlementsChoiceList.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		NewFilterGroupItem.GroupType = DataCompositionFilterItemsGroupType.NotGroup;
		NewFilterGroupItem.Use = True;
		
		NewFilterGroupItemReservationDocument = NewFilterGroupItem.Items.Add(Type("DataCompositionFilterItemGroup"));
		NewFilterGroupItemReservationDocument.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		NewFilterGroupItemReservationDocument.Use = True;
		
		NewFilterItem = NewFilterGroupItemReservationDocument.Items.Add(Type("DataCompositionFilterItem"));
		NewFilterItem.LeftValue = New DataCompositionField("ReservationDocument");
		NewFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		NewFilterItem.RightValue = RowSettlements.ReservationDocument;
		NewFilterItem.Use = True;
		If Not ValueIsFilled(RowSettlements.ReservationDocument) Then
			NewFilterItem = NewFilterGroupItemReservationDocument.Items.Add(Type("DataCompositionFilterItem"));
			NewFilterItem.LeftValue = New DataCompositionField("ReservationDocument");
			NewFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			NewFilterItem.RightValue = Undefined;
			NewFilterItem.Use = True;
		EndIf;
		NewFilterItem = NewFilterGroupItem.Items.Add(Type("DataCompositionFilterItem"));
		NewFilterItem.LeftValue = New DataCompositionField("Document");
		NewFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		NewFilterItem.RightValue = RowSettlements.Document;
		NewFilterItem.Use = True;
		
		NewFilterItem = NewFilterGroupItem.Items.Add(Type("DataCompositionFilterItem"));
		NewFilterItem.LeftValue = New DataCompositionField("AmountBalance");
		NewFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		NewFilterItem.RightValue = RowSettlements.GrossAmount;
		NewFilterItem.Use = True;
	EndDo;
EndProcedure

Procedure SettlementsChange(Form, FilterValue) Export
	Form.SettlementsCount = Form.Settlements.Count();
	If Form.Items.Find("SettlementsSettlementsChoice")<> Undefined
		AND Form.Items.SettlementsSettlementsChoice.Check Then
		SetFilterSettlementsChoiceList(Form, FilterValue);
	EndIf;
	Form.SettlementsTotalAmount = Form.Settlements.Total("GrossAmount");
EndProcedure

Procedure OpenSettlementsCurrentDocument(CurrentData, CurrentItem) Export
	If CurrentData = Undefined Then
		Return;
	EndIf;
	If CurrentItem.Name = "SettlementsChoiceListReservationDocument" And ValueIsFilled(CurrentData.ReservationDocument) Then
		ShowValue(Undefined, CurrentData.ReservationDocument);
	ElsIf ValueIsFilled(CurrentData.Document) Then
		ShowValue(Undefined, CurrentData.Document);
	EndIf;
EndProcedure

Procedure PostPrintClose(Form) Export
    // by Jack 18.05.2017
	//ObjectsToPrint = New Array;
	//ObjectsToPrint.Add(Form.Object.Ref);
	//PrintManagerClient.CallPrintoutSettingsForm(ObjectsToPrint, New Structure("Source", New Structure("FormName,UUID", "Document." + Form.ObjectMetadataName + ".Form.DocumentFormManaged", New UUID)));
	Form.Modified = False;
	Form.Close();
	NotifyChanged(Form.Object.Ref);
EndProcedure

Procedure OpenPriceAndDiscountSettings(Form, CustomerValue = Undefined) Export
	Object = Form.Object;
	If CustomerValue = Undefined Then
		ParametersStructure = Form.GetParametersPriceAndDiscountSettings();
	Else
		ParametersStructure = Form.GetParametersPriceAndDiscountSettings(CustomerValue);
	EndIf;
	
	Notify = New NotifyDescription(
		"RecalculatePriceAndDiscount",
		Form, 
		New Structure);
	OpenForm("DataProcessor.PriceAndDiscountsRecalculation.Form.FormManaged", ParametersStructure, Form,,,,Notify);
EndProcedure

Procedure SetCommandsInterface(Form, Cancel, FormInformation) 
	If Not Form.Items.Find("FormCommonCommandShowBookkeepingOperationCommand") = Undefined Then
		Form.Items.FormCommonCommandShowBookkeepingOperationCommand.Visible = CommonAtServer.GetVisibilityBookkeepingOperationCommand(Form.FormName);
	EndIf;
	If Not Form.Items.Find("FormCommonCommandAddAdditionalAttribute") = Undefined Then
		Form.Items.FormCommonCommandAddAdditionalAttribute.OnlyInAllActions = True;
		Form.Items.FormCommonCommandAddAdditionalAttribute.Visible = FormInformation.Type = "OBJECT";
	EndIf;
	If Not Form.Items.Find("FormCommonCommandPrintSettings") = Undefined Then
		Form.Items.FormCommonCommandPrintSettings.OnlyInAllActions = True;
	EndIf;
	If Not Form.Items.Find("FormCommonCommandRecordsReport") = Undefined Then
		Form.Items.FormCommonCommandRecordsReport.OnlyInAllActions = True;
	EndIf;
	If Not Form.Items.Find("FormCreateBasedOn") = Undefined Then
		Form.Items.FormCreateBasedOn.Picture = PictureLib.InputOnBasis;
		Form.Items.FormCreateBasedOn.Representation = ButtonRepresentation.Picture;
	EndIf;
	If Not Form.Items.Find("FormCommonCommandEditObjectFiles") = Undefined Then
		Form.Items.FormCommonCommandEditObjectFiles.OnlyInAllActions = True;
		Form.Items.FormCommonCommandEditObjectFiles.Visible = FormInformation.Type = "OBJECT";
	EndIf;
EndProcedure

Procedure ShowHideColumns(Val Visibility, ColumnsStructure) Export
	
	For Each KeyAndValue In ColumnsStructure Do
		
		KeyAndValue.Value.Visible = Visibility;
		
	EndDo;	
	
EndProcedure

Procedure EndQuestionGenerateSalesReturnOrder(QuestionAnswer, DocumentParameters) Export
	If QuestionAnswer = DialogReturnCode.Yes Then
		OpenForm("Document.SalesReturnOrder.ObjectForm", New Structure("FillingData", DocumentParameters.SalesInvoice));
	EndIf;
EndProcedure

Procedure ChangeDocumentsHeaderData(Form, Item = Undefined) Export
	//If Not Item = Undefined AND (Item.Name = "NumberPreview" Or Item.Name = "Number") Then
	//	Form.Object.ManualChangeNumber = True;
	//EndIf;
	If Form.Object.ManualChangeNumber AND (Item.Name = "NumberPreview" Or Item.Name = "Number")  Then
		Form.Object.Number = Item.EditText;
	EndIf;
	NewHeaderValue = New Structure();
	For Each HeaderValue In Form.HeaderValue Do
		If HeaderValue.Key = "CurrentPrefix" Or HeaderValue.Key = "CurrentNumber" Then
			NewHeaderValue.Insert(HeaderValue.Key, Form.HeaderValue[HeaderValue.Key]);
			Continue;
		EndIf;
		NewHeaderValue.Insert(HeaderValue.Key, Form.Object[HeaderValue.Key]);
	EndDo;
	ChangeDocumentsHeader(Form, NewHeaderValue, New Structure(Form.HeaderValue));
	
	If Not Form.Object.ManualChangeNumber And Not Form.Object.Ref.IsEmpty() And Form.HeaderValue.CurrentNumber <> Form.Object.Number Then
		EndMessage = New NotifyDescription("EndMessage", DocumentsFormAtClient, New Structure());
		//If Left(Form.Object.Number, StrLen(Form.HeaderValue.CurrentPrefix)) <> Form.HeaderValue.CurrentPrefix Then
		//	ShowQueryBox(EndMessage, NStr("ru='Документ будет перенумерован'; pl='Numer dokumentu został zmieniony';en='Document number is changed'"), QuestionDialogMode.OK);
		//EndIf;
		Form.Object.Number = Form.HeaderValue.CurrentNumber;
	EndIf;
EndProcedure

Procedure EndMessage(QuestionAnswer, Parameters) Export
	
EndProcedure

#Region BookkeepingOperationsTemplates
Procedure EditFormula(ThisForm, FillingMethod, TableKind, TableName, TableBoxName, TypeRestriction, OpenedFromWizard=False) Export
	
	If FillingMethod = PredefinedValue("Enum.FieldFillingMethods.Parameter") Then
		
		FormParameters = New Structure;
		FormParameters.Insert("DocumentBase", ThisForm.Object.DocumentBase);
		FormParameters.Insert("FilterByType", True);
		FormParameters.Insert("Formula", ThisForm.Formula);
		FormParameters.Insert("TableKind", TableKind);
		FormParameters.Insert("TableName", TableName);
		FormParameters.Insert("TableBoxName", TableBoxName);
		FormParameters.Insert("TypeRestriction", TypeRestriction);
		FormParameters.Insert("OpenedFromWizard", OpenedFromWizard);		
		
		OpenForm("Catalog.BookkeepingOperationsTemplates.Form.ParameterSelectionManaged", FormParameters, ThisForm, , , , New NotifyDescription("EditingFormulaOnClose", ThisForm));
		
	ElsIf FillingMethod = PredefinedValue("Enum.FieldFillingMethods.Formula") Then	
		
		FormParameters = New Structure;
		FormParameters.Insert("DocumentBase", ThisForm.Object.DocumentBase);
		FormParameters.Insert("Formula", ThisForm.Formula);
		FormParameters.Insert("TableKind", TableKind);
		FormParameters.Insert("TableName", TableName);
		FormParameters.Insert("TableBoxName", TableBoxName);
		FormParameters.Insert("FormulaPresentation", ThisForm.FormulaPresentation);
		FormParameters.Insert("OpenedFromWizard", OpenedFromWizard);				
		
		OpenForm("Catalog.BookkeepingOperationsTemplates.Form.EditFormulaSimpleManaged", FormParameters, ThisForm, , , , New NotifyDescription("EditingFormulaOnClose", ThisForm));
		
	ElsIf FillingMethod = PredefinedValue("Enum.FieldFillingMethods.ProgrammisticFormula") Then		
		
		FormParameters = New Structure;
		FormParameters.Insert("DocumentBase", ThisForm.Object.DocumentBase);
		FormParameters.Insert("Formula", ThisForm.Formula);
		FormParameters.Insert("TableKind", TableKind);
		FormParameters.Insert("TableName", TableName);
		FormParameters.Insert("TableBoxName", TableBoxName);
		FormParameters.Insert("OpenedFromWizard", OpenedFromWizard);				
		
		OpenForm("Catalog.BookkeepingOperationsTemplates.Form.EditFormulaProgrammisticManaged", FormParameters, ThisForm, , , , New NotifyDescription("EditingFormulaOnClose", ThisForm));
		
	EndIf;
	
EndProcedure

Procedure CreateNewParameter(ItemForm, ThisForm, TableBoxName, ItemsStructure = Undefined) Export
	FormParameters = GetNewParameterStructure(ItemForm, TableBoxName);
	OpenForm("Catalog.BookkeepingOperationsTemplates.Form.ParameterManaged", FormParameters, ThisForm, ThisForm.UUID, , , New NotifyDescription("NewParameterOnCloseResult", ThisForm,ItemsStructure));	
EndProcedure

Function GetNewParameterStructure(ThisForm, TableBoxName) Export
	TableBox = ThisForm.Items.Find(TableBoxName);
	
	FormParameters = New Structure;
	FormParameters.Insert("DocumentBase", ThisForm.Object.DocumentBase);
	FormParameters.Insert("IsNew",True);
	
	If TableBox <> Undefined Then 
		CurrentData = TableBox.CurrentData;		
		If CurrentData <> Undefined Then			
			If TableBox.CurrentItem <> Undefined Then			
				CurrentColumnName = ThisForm.GetObjectFieldName(TableBox.CurrentItem.Name);
			Else
				CurrentColumnName = Undefined;
			EndIf;				
		EndIf;	
		
		If CurrentData <> Undefined
			AND CurrentColumnName <> Undefined
			AND CurrentColumnName <> "LineNumber"
			AND CurrentColumnName <> "Condition" Then
			DocumentsFormAtServer.GetTableKindAndName(ThisForm.Object ,FormParameters, TableBoxName, CurrentData.GetID(), CurrentColumnName);			
		EndIf;		
	EndIf;
		
	Return FormParameters;
EndFunction 

Function GetStrCurrentRecord(RootForm,TableBoxName) Export
	StrCurrentRecord = New Structure("TableBoxCurrentIndexOfRecord, TableBoxCurrentColumn", 0, ""); 
	CurrentTableBox = RootForm.Items.Find(TableBoxName);
	If CurrentTableBox<>Undefined  Then
		StrCurrentRecord.TableBoxCurrentColumn = RootForm.GetObjectFieldName(CurrentTableBox.CurrentItem.Name);		
		StrCurrentRecord.TableBoxCurrentIndexOfRecord = CurrentTableBox.CurrentData.GetID()		
	EndIf;
	
	Return StrCurrentRecord;
EndFunction 

Procedure ExpandTreeRows(Item,Tree)	Export
	For Each Row In Tree.GetItems() Do
		Item.Expand(Row.GetID(),True);
	EndDo;	
EndProcedure

#EndRegion