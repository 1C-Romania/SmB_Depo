
Procedure SetWaightAndVolumeColumnsHeaderText(TableBox, WeightColumnName = "Weight", VolumeColumnName = "Volume", GrossWeightColumnName = "") Export
	
	TableBox.Columns[WeightColumnName].HeaderText = TableBox.Columns[WeightColumnName].HeaderText + " (" + Constants.WeightUnitOfMeasure.Get() + ")";
	TableBox.Columns[VolumeColumnName].HeaderText = TableBox.Columns[VolumeColumnName].HeaderText + " (" + Constants.VolumeUnitOfMeasure.Get() + ")";
	
	If NOT IsBlankString(GrossWeightColumnName) Then
		TableBox.Columns[GrossWeightColumnName].HeaderText = TableBox.Columns[GrossWeightColumnName].HeaderText + " (" + Constants.WeightUnitOfMeasure.Get() + ")";
	EndIf;	
	
EndProcedure

Function GetDocumentsTotalString(Document, AmountType, Currency) Export 
	
	TotalVAT = Document.ItemsLines.Total("VAT");
	TotalVATStr = NStr("en='; VAT: ';pl='; VAT: '");
	
	TotalAmount = Document.ItemsLines.Total("Amount") + ?(AmountType = Enums.NetGross.Gross, 0, TotalVAT);
	TotalAmountStr = NStr("en='Totals. Amount: ';pl='Sumy. Kwota: '");
	
	Return TotalAmountStr + FormatAmount(TotalAmount) + TotalVATStr + FormatAmount(TotalVAT) + " " + Currency;
	
EndFunction // GetDocumentsTotalString()

// This function leaved for compatibility.
// If no references in configuration on this function, it can be deleted.
Function WriteNewObjectInForm(ObjectForm) Export 
	
	Return WriteObjectInForm(ObjectForm, ObjectForm.IsNew());
	
EndFunction // WriteNewObjectInForm()

Function WriteObjectInForm(ObjectForm, WriteFlag) Export 
	
	If Not WriteFlag Then
		Return True;
	EndIf;
	
	If Documents.AllRefsType().ContainsType(TypeOf(ObjectForm.ThisObject.Ref)) Then
		QuestionText = NStr("en='Please, first save the document. Save now?';pl='Najpierw zapisz dokument. Czy zapisać teraz?'");
	Else // Catalogs, Charts of characteristic types, Charts of accounts, Charts of calculation types
		QuestionText = NStr("en='Please, first save the element. Save now?';pl='Najpierw zapisz element. Czy zapisać teraz?'");
	EndIf;
		
	Answer = DoQueryBox(QuestionText, QuestionDialogMode.YesNo);
		
	If Answer <> DialogReturnCode.Yes Then
		Return False;
	Else
		Try
			Return ObjectForm.WriteInForm();
		Except
			Message(ErrorDescription());
			Return False;
		EndTry;
	EndIf;
	
EndFunction // WriteNewObjectInForm()

Function GetWightOfDocument(ItemLines) Export	
	
	Query = New Query;
	Query.Text = "SELECT
	             |	Items.Item,
	             |	Items.Quantity,
	             |	Items.UnitOfMeasure
	             |INTO TempTableItems
	             |FROM
	             |	&DistributionTable AS Items
	             |;
	             |
	             |////////////////////////////////////////////////////////////////////////////////
	             |SELECT
	             |	ItemsUnitsOfMeasure.Weight,
	             |	ItemsUnitsOfMeasure.GrossWeight,
	             |	TempTableItems.Item.Code AS ItemCode,
	             |	TempTableItems.Quantity
	             |FROM
	             |	TempTableItems AS TempTableItems
	             |		LEFT JOIN Catalog.Items.UnitsOfMeasure AS ItemsUnitsOfMeasure
	             |		ON TempTableItems.Item = ItemsUnitsOfMeasure.Ref
	             |			AND TempTableItems.UnitOfMeasure = ItemsUnitsOfMeasure.UnitOfMeasure";
	
	Query.SetParameter("DistributionTable", ItemLines);
	QueryResult = Query.ExecuteBatch();
	QueryUnload = QueryResult[1].Unload();
	
	WeightTotal = 0;
	GrossWeightTotal = 0;
	
	For each Item in QueryUnload Do
		
		WeightTotal = WeightTotal + (Item.Weight*Item.Quantity);
		GrossWeightTotal = GrossWeightTotal + (Item.GrossWeight*Item.Quantity); 
		
		If Item.Weight = 0 Then
			Message("Towar " + Item.ItemCode + " nie posiada wagi");
		EndIf;
	EndDo;
	
	Array = new Array();
	Array.Add(WeightTotal);
	Array.Add(GrossWeightTotal);
	
	Return Array;
	
EndFunction

Function GetDocumentPricesValueList(Document, Item, PriceColumnName = "Price") Export
	
	If Document <> Undefined Then
		DocumentName = Document.Metadata().Name;
		
		Query = New Query;
		Query.Text = "SELECT
		|	DocumentItemsLines." + PriceColumnName + "
		|FROM
		|	Document." + DocumentName + ".ItemsLines AS DocumentItemsLines
		|WHERE
		|	DocumentItemsLines.Ref = &Document
		|	AND DocumentItemsLines.Item = &Item";
		
		Query.SetParameter("Document", Document);
		Query.SetParameter("Item"    , Item);
		
		Selection = Query.Execute().Select();
		
		ValueList = New ValueList;
		
		While Selection.Next() Do
			ValueList.Add(Selection.Price, FormatAmount(Selection.Price));
		EndDo;
	Else
		ValueList = New ValueList;
	EndIf;
	
	Return ValueList;
	
EndFunction // GetDocumentPricesValueList()

Function GetDocumentPricesAndInitialPriceValueList(Document, Item, PriceColumnName = "Price", InitialPriceColumnName = "InitialPrice",PricePromotionColumnName = "PricePromotion") Export
	
	If Document <> Undefined Then
		DocumentName = Document.Metadata().Name;
		
		Query = New Query;
		Query.Text = "SELECT
		|	DocumentItemsLines." + PriceColumnName + " AS Price,
		|	DocumentItemsLines." + PricePromotionColumnName + " AS PricePromotion,
		|	DocumentItemsLines." + InitialPriceColumnName + " AS InitialPrice
		|FROM
		|	Document." + DocumentName + ".ItemsLines AS DocumentItemsLines
		|WHERE
		|	DocumentItemsLines.Ref = &Document
		|	AND DocumentItemsLines.Item = &Item";
		
		Query.SetParameter("Document", Document);
		Query.SetParameter("Item"    , Item);
		
		Selection = Query.Execute().Select();
		
		ValueList = New ValueList;
		
		While Selection.Next() Do
			ValueList.Add(New Structure("Price, InitialPrice, PricePromotion",Selection.Price,Selection.InitialPrice, Selection.PricePromotion));
		EndDo;
	Else
		ValueList = New ValueList;
	EndIf;
	
	Return ValueList;
	
EndFunction // GetDocumentPricesValueList()

Function GetSupplierPricesValueList(Supplier, Item, Date) Export 
		
	Query = New Query;
	Query.Text = "SELECT
	             |	InnerQuery.Price AS Price,
	             |	InnerQuery.Currency AS Currency,
	             |	InnerQuery.Date AS Date,
	             |	PurchasePrices.Quantity AS Quantity,
	             |	PurchasePrices.UnitOfMeasure AS UnitOfMeasure
	             |FROM
	             |	(SELECT TOP 5
	             |		PurchasePrices.Item AS Item,
	             |		PurchasePrices.Supplier AS Supplier,
	             |		PurchasePrices.Price AS Price,
	             |		PurchasePrices.Currency AS Currency,
	             |		MAX(PurchasePrices.Period) AS Date
	             |	FROM
	             |		InformationRegister.PurchasePrices AS PurchasePrices
	             |	WHERE
	             |		PurchasePrices.Supplier = &Supplier
	             |		AND PurchasePrices.Item = &Item
	             |		AND PurchasePrices.Period < &Date
	             |	
	             |	GROUP BY
	             |		PurchasePrices.Supplier,
	             |		PurchasePrices.Item,
	             |		PurchasePrices.Price,
	             |		PurchasePrices.Currency
	             |	
	             |	ORDER BY
	             |		Date DESC) AS InnerQuery
	             |		INNER JOIN InformationRegister.PurchasePrices AS PurchasePrices
	             |		ON PurchasePrices.Period = InnerQuery.Date
	             |			AND PurchasePrices.Item = InnerQuery.Item
	             |			AND PurchasePrices.Supplier = InnerQuery.Supplier
	             |
	             |ORDER BY
	             |	Date DESC";
	
	Query.SetParameter("Supplier", Supplier);
	Query.SetParameter("Item"    , Item);
	Query.SetParameter("Date"    , Date);
	
	Selection = Query.Execute().Select();
	
	ValueList = New ValueList;
	
	While Selection.Next() Do
		ValueList.Add(Selection.Price, FormatAmount(Selection.Price) + " " + Selection.Currency + " (" + Format(Selection.Quantity, "NFD=3") + " " + Selection.UnitOfMeasure + NStr("en=' from ';pl=' od '") + Format(Selection.Date, "DLF=D") + ")" );
	EndDo;
	
	Return ValueList;
	
EndFunction // GetSupplierPricesValueList()

Function GetDocumentFirstPrice(Document, Item) Export 
	
	PriceValueList = GetDocumentPricesValueList(Document, Item);
	If PriceValueList.Count() = 1 Then
		Return PriceValueList[0].Value;
	Else
		Return 0;
	EndIf;
	
EndFunction // GetDocumentFirstPrice()

Function GetDocumentFirstPriceAndInitialPriceStructure(Document, Item) Export 
	
	PriceValueList = GetDocumentPricesAndInitialPriceValueList(Document, Item);
	If PriceValueList.Count() = 1 Then
		Return PriceValueList[0].Value;
	Else
		Return New Structure("Price, InitialPrice, PricePromotion",0,0,Catalogs.SalesPricePromotions.EmptyRef());
	EndIf;
	
EndFunction // GetDocumentFirstPrice()


Function GetSalesInvoicePricePromotionsValueList(Document, Item) Export 
	
	DocumentName = Document.Metadata().Name;
	
	Query = New Query;
	Query.Text = "SELECT
	             |	SalesInvoicesTurnovers.PricePromotion
	             |FROM
	             |	AccumulationRegister.SalesInvoices.Turnovers(
	             |			&BeginPeriod,
	             |			,
	             |			,
	             |			SalesInvoice = &SalesInvoice
	             |				AND Item = &Item) AS SalesInvoicesTurnovers
	             |WHERE
	             |	SalesInvoicesTurnovers.InvoiceRecordType = VALUE(Enum.InvoiceRecordType.Invoice)";
	
	Query.SetParameter("BeginPeriod" , Document.Date);
	Query.SetParameter("SalesInvoice", Document);
	Query.SetParameter("Item"        , Item);
	
	Selection = Query.Execute().Select();
	
	ValueList = New ValueList;
	
	While Selection.Next() Do
		ValueList.Add(Selection.PricePromotion, Selection.PricePromotion);
	EndDo;
	
	Return ValueList;
	
EndFunction // GetSalesInvoicePricePromotionsValueList()

Function GetPurchaseInvoiceCostArticlesPricesValueList(Document, CostArticle) Export 
	                    //
	DocumentName = Document.Metadata().Name;
	
	Query = New Query;
	Query.Text = "SELECT
	             |	PurchaseInvoices.Price
	             |FROM
	             |	AccumulationRegister.PurchaseInvoices AS PurchaseInvoices
	             |WHERE
	             |	PurchaseInvoices.InvoiceRecordType = VALUE(Enum.InvoiceRecordType.Invoice)
	             |	AND PurchaseInvoices.PurchaseInvoice = &PurchaseInvoice
	             |	AND PurchaseInvoices.CostArticle = &CostArticle
	             |	AND PurchaseInvoices.Period >= &BeginPeriod";
	
	Query.SetParameter("BeginPeriod" , Document.Date);
	Query.SetParameter("PurchaseInvoice", Document);
	Query.SetParameter("CostArticle"        , CostArticle);
	
	Selection = Query.Execute().Select();
	
	ValueList = New ValueList;
	
	While Selection.Next() Do
		ValueList.Add(Selection.Price, FormatAmount(Selection.Price));
	EndDo;
	
	Return ValueList;
	
EndFunction // GetPurchaseInvoiceCostArticlesPricesValueList()

Function GetExchangeRateRepresentation(CurrencyDescription, NationalCurrencyDescription, UseBrackets = False) Export 
	
	ExchangeRateRepresentation = "" + NationalCurrencyDescription + NStr("en=' per 1 ';pl=' na 1 '") + CurrencyDescription;
	
	If UseBrackets Then
		ExchangeRateRepresentation = "(" + ExchangeRateRepresentation + ")";
	EndIf;
	
	Return ExchangeRateRepresentation;
	
EndFunction // CommonAtServer.GetItemsUnitsOfMeasureValueList()

Function GetDeliveryTimeList() Export
	
	DeliveryTimeList = New ValueList;
	
	InitialTime = '000101010600';
	FinishTime  = '000101012000';
	
	While InitialTime <= FinishTime Do
		DeliveryTimeList.Add(InitialTime, Format(InitialTime, "DF=HH:mm"));
		InitialTime = InitialTime + 30*60;
	EndDo;
	
	Return DeliveryTimeList;
	
EndFunction // GetDeliveryTimeList()

Procedure GlobalExchangeRateStartListChoice(Control, StandartProcessing, Form, Currency, OutExchangeRateDate = Undefined, OutNBPTableNumber = Undefined) Export
	
	StandartProcessing = False;
	
	Query = New Query;
	Query.Text = "SELECT TOP 9
	             |	CurrencyExchangeRates.ExchangeRate,
	             |	CurrencyExchangeRates.Period AS Period,
	             |	CurrencyExchangeRates.NBPTableNumber
	             |FROM
	             |	InformationRegister.CurrencyExchangeRates AS CurrencyExchangeRates
	             |WHERE
	             |	CurrencyExchangeRates.Currency = &Currency
	             |
	             |ORDER BY
	             |	Period DESC";
	
	Query.SetParameter("Currency", Currency);
	Selection = Query.Execute().Select();
	
	ExchangeRatesValueList = New ValueList;
	
	While Selection.Next() Do
		
		ExchangeRateStructure = New Structure("ExchangeRate, Period, NBPTableNumber", Selection.ExchangeRate, Selection.Period, Selection.NBPTableNumber);
		ExchangeRatesValueList.Add(ExchangeRateStructure, "" + Selection.ExchangeRate + " (" + Selection.Period + ")");
		
	EndDo;
	
	ExchangeRatesValueList.Add(Undefined, NStr("en=""Choose from list...""; pl=""Wybierz z listy..."""));
	
	CurrentValue = Undefined;
	
	For i=0 To ExchangeRatesValueList.Count()-2 Do
		
		If ExchangeRatesValueList[i].Value.ExchangeRate = Control.Value 
			AND (OutExchangeRateDate = Undefined OR BegOfDay(ExchangeRatesValueList[i].Value.Period) = BegOfDay(OutExchangeRateDate))
			AND (OutNBPTableNumber = Undefined OR ExchangeRatesValueList[i].Value.NBPTableNumber = OutNBPTableNumber) Then
			CurrentValue = i;
			Break;
		EndIf;	
		
	EndDo;	
	
	ValueListItem = Form.ChooseFromList(ExchangeRatesValueList, Control, CurrentValue);
	
	If ValueListItem = Undefined Then
		Return;
	ElsIf ValueListItem.Value = Undefined Then
		
		Parameters = New Structure;
		Parameters.Insert("Filter",New Structure("Currency",Currency));
		Parameters.Insert("ReturnRow",(OutExchangeRateDate<>Undefined));
		Parameters.Insert("ChoiceMode",True);
		Parameters.Insert("CloseOnChoice",True);
		OpenForm("InformationRegister.CurrencyExchangeRates.ListForm",Parameters,?(OutExchangeRateDate<>Undefined,Form,Control),Control);		
	Else
		Control.Value = ValueListItem.Value.ExchangeRate;
		OutExchangeRateDate = ValueListItem.Value.Period;
		OutNBPTableNumber = ValueListItem.Value.NBPTableNumber;
	EndIf;
	
EndProcedure // GlobalExchangeRateStartListChoice()

Procedure SetFormMainActionsButtonsProperties(Form) Export
	
	Form.Controls.FormMainActions.Buttons.FormMainActionsPost.Text = NStr("en='Post';pl='Zatwierdź'");
	Form.Controls.FormMainActions.Buttons.FormMainActionsOK.DefaultButton = True;
	
	Form.Controls.FormMainActions.Buttons.FormMainActionsSave.Text = NStr("en = 'Save draft'; pl = 'Zapisz wersję roboczą'");
	Form.Controls.FormMainActions.Buttons.FormMainActionsSave.Enabled = Not Form.Posted;
	
	Form.Controls.FormMainActions.Buttons.FormMainActionsOK.Text = NStr("en='Post and Close';pl='Zatwierdź i zamknij'");
	
EndProcedure // SetFormMainActionsButtonsProperties()

Procedure AddFormMainActionsBookkeepingButton(Form) Export	
	
	If SessionParameters.IsBookkeepingAvailable Then
		
		Try
			DocumentList = Form.DocumentList;
		Except
			DocumentList = Undefined;
		EndTry; 
		
		If DocumentList <> Undefined Then
			Try
				TypeOfDocument = TypeOf(Form.DocumentList.Filter.Ref.Value);
			Except
				TypeOfDocument = Undefined;
			EndTry;	
			
		Else
			Try
				TypeOfDocument = TypeOf(Form.Ref);
			Except
				TypeOfDocument = Undefined;
			EndTry;
		EndIf;	
		
		If TypeOfDocument <> Undefined Then
			
			If TypeOfDocument = Type("DocumentRef.BookkeepingOperation") Then
				Return;
			EndIf;
			
			RecordKey = InformationRegisters.BookkeepingPostingSettings.Get(New Structure("Object",New (TypeOfDocument)));
			If RecordKey.BookkeepingPostingType = Enums.BookkeepingPostingTypes.DontPost Then	
				Return;
			EndIf;
			
		EndIf;	
		
		CP = Form.Controls.FormActions;
		NewAction  = New Action("FormActionsShowBookkeepingOperation");
		ButtonType = CommandBarButtonType.Action;
		
		If CP.Buttons <> Undefined Then
			For Each ButtonsRow In CP.Buttons Do
				
				If ButtonsRow.Name = "ShowRegisterRecords" Then
					
					If ValueIsNotFilled(CP.Buttons.Find("ShowBookkeepingOperation")) Then
						Index = 1 + CP.Buttons.IndexOf(CP.Buttons["ShowRegisterRecords"]);
						NewButton = CP.Buttons.Insert(Index, "ShowBookkeepingOperation", ButtonType,, NewAction);
						If NewButton <> Undefined Then
							NewButton.Picture = PictureLib.ShowBookkeepingOperation;
							NewButton.Text	  = NStr("en='Show bookkeeping operation';pl='Pokaż DK';ru='Показать бухгалтерские проводки'");
							NewButton.ToolTip = NStr("en='Show bookkeeping operation';pl='Pokaż dowód księgowy';ru='Показать бухгалтерские проводки'");
						EndIf;
					EndIf;
					
				ElsIf (ButtonsRow.ButtonType = CommandBarButtonType.Popup Or ButtonsRow.ButtonType = CommandBarButtonType.Action)
					And ButtonsRow.Buttons <> Undefined Then
					
					FillCommandBarButtonType(ButtonsRow, ButtonsRow.Buttons, ButtonType, NewAction);
					
				EndIf;
				
			EndDo;
		EndIf;
		
	EndIf;
	
EndProcedure // AddFormMainActionsBookkeepingButton()

Procedure AddChangeButton(Form) Export
	
	If NOT Form.ReadOnly Then
		Return;
	EndIf;
	
	CP = Form.Controls.FormActions;
	NewAction  = New Action("FormActionsChange");
	ButtonType = CommandBarButtonType.Action;
	ButtonName = "ChangeDocumentAction";
	NestedStructureButtonName = "NestedStructure";
	
	If CP.Buttons <> Undefined Then
		For Each ButtonsRow In CP.Buttons Do
			
			If ButtonsRow.Name = NestedStructureButtonName Then
				
				If ValueIsNotFilled(CP.Buttons.Find(ButtonName)) Then
					Index = CP.Buttons.IndexOf(CP.Buttons[NestedStructureButtonName]);
					NewButton = CP.Buttons.Insert(Index, ButtonName, ButtonType,, NewAction);
					If NewButton <> Undefined Then
						NewButton.Text	  = NStr("en = 'Change document'; pl = 'Zmień dokument'");
						NewButton.ToolTip = NStr("en = 'Change document'; pl = 'Zmień dokument'");
					EndIf;
					NewSeparator = CP.Buttons.Insert(Index+1, "ChangeDocumentSeparator", CommandBarButtonType.Separator);
				EndIf;
				
			EndIf;
			
		EndDo;
	EndIf;	
	
EndProcedure

Procedure RemoveFormBookkeepingDefinitionButton(Form) Export
	
	If NOT SessionParameters.IsBookkeepingAvailable Then
		
		CP = Form.Controls.FormActions;
		
		If CP.Buttons <> Undefined Then
			FoundButton = CP.Buttons.Find("BookkeepingDefinition");
			
			If FoundButton <> Undefined Then
				CP.Buttons.Delete(FoundButton);
			EndIf;	
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillCommandBarButtonType(ButtonsRow, Buttons, ButtonType, NewAction)
	
	If ButtonsRow.Name = "ShowRegisterRecords" Then
		
		If Buttons.Find("ShowBookkeepingOperation")=Undefined Then
			Index = 1 + Buttons.IndexOf(Buttons["ShowRegisterRecords"]);
			NewButton = Buttons.Insert(Index, "ShowBookkeepingOperation", ButtonType,, NewAction);
			If NewButton <> Undefined Then
				NewButton.Picture = PictureLib.ShowBookkeepingOperation;
				NewButton.Text	  = NStr("en='Show bookkeeping operation';pl='Pokaż DK';ru='Показать бухгалтерские проводки'");
				NewButton.ToolTip = NStr("en='Show bookkeeping operation';pl='Pokaż dowód księgowy';ru='Показать бухгалтерские проводки'");
			EndIf;
		EndIf;
		
	ElsIf (ButtonsRow.ButtonType = CommandBarButtonType.Popup Or ButtonsRow.ButtonType = CommandBarButtonType.Action)
			And ButtonsRow.Buttons <> Undefined Then
			
		For Each Button In ButtonsRow.Buttons Do
			FillCommandBarButtonType(Button, ButtonsRow.Buttons, ButtonType, NewAction);
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure ShowBookkeepingOperation(DocumentRef) Export 
	
	BookkeepingIsRegisterRecords = FALSE;
	
	MetadataDocument = Metadata.Documents[DocumentRef.Metadata().Name];
	
	For each RegisterRecords in MetadataDocument.RegisterRecords do
		If Metadata.AccountingRegisters.Bookkeeping = RegisterRecords Then
			BookkeepingIsRegisterRecords = TRUE;
			Break;
		EndIf;

	EndDo;
	
	// If base document is BO
	If TypeOf(DocumentRef) = TypeOf(Documents.BookkeepingOperation.EmptyRef()) or BookkeepingIsRegisterRecords = TRUE   Then
		Return;		
	ElsIf BookkeepingIsRegisterRecords = FALSE Then
		
		Query = New Query;
		
		Query.Text = "SELECT
		             |	BookkeepingOperation.Ref AS BookkeepingOperation
		             |FROM
		             |	Document.BookkeepingOperation AS BookkeepingOperation
		             |WHERE
		             |	BookkeepingOperation.DocumentBase = &ReportsDocument";		
		Query.SetParameter("ReportsDocument",DocumentRef);
		QueryResult = Query.Execute();
		If QueryResult.IsEmpty() Then
			// 	There is no BO
			RecordKey = InformationRegisters.BookkeepingPostingSettings.Get(New Structure("Object",New (TypeOf(DocumentRef))));
			BookkeepingPostingType = RecordKey.BookkeepingPostingType;
			If NOT DocumentRef.Posted Then
				ShowMessageBox(, NStr("en = 'This document was not posted. Unposted document could not have no bookkeeping operation.'; pl = 'Ten dokument nie został zatwierdzony. Nie zatwierdzony document nie może posiadać DK.'"));
			ElsIf BookkeepingPostingType = Enums.BookkeepingPostingTypes.DontPost Then	
				ShowMessageBox(, NStr("en = 'This document could not be bookkeeping posted. Please check your bookkeeping posting settings.'; pl = 'Ten dokument nie może być zaksięgowany. Sprawdź ustawienia księgowania.'"));
			Else	
				If AccessRight("Posting",Metadata.Documents.BookkeepingOperation) Then
					If DoQueryBox(NStr("en = 'For this document bookkeeping operation does not exists. Do you want to create a new one bookkeeping operation?'; pl = 'Na podstawie tego dokumentu nie został zaksięgowany dowód księgowy. Czy chcesz stworzyć nowy dowód księgowy?'"),QuestionDialogMode.YesNo) = DialogReturnCode.Yes Then
						NewDocumentForm = Documents.BookkeepingOperation.GetNewDocumentForm(,,DocumentRef);
						NewDocumentForm.Company = DocumentRef.Company;
						NewDocumentForm.Date = DocumentRef.Date;
						NewDocumentForm.OperationType = Enums.OperationTypesBookkeepingOperation.BasedOnDocument;
						NewDocumentForm.DocumentBase = DocumentRef;
						NewDocumentForm.InitialDocumentBase = DocumentRef;
						NewDocumentForm.DocumentBaseOnChangeEventHandler();
						BookkeepingOperationTemplate = Undefined;
						Result = BookkeepingCommon.GetRecommendSchemaForDocument(DocumentRef, BookkeepingOperationTemplate, False);
						If Result = 1 Then
							NewDocumentForm.BookkeepingOperationsTemplate = BookkeepingOperationTemplate;
							NewDocumentForm.Description = BookkeepingOperationTemplate.DescriptionForBookkeepingOperation;
							NewDocumentForm.PartialJournal = BookkeepingOperationTemplate.PartialJournal;
							NewDocumentForm.GenerateRecordsFromBookkeepingOperationsTemplates();
						Else
							NewDocumentForm.Manual = True;
						EndIf;
						
						NewDocumentForm.Open();
					EndIf;	
				Else	
					ShowMessageBox(, NStr("en = 'For this document bookkeeping operation does not exists. You don''t have enough permissions to create a new one!'; pl = 'Na podstawie tego dokumentu nie został zaksięgowany dowód księgowy. Nie masz wystarczająco uprawnień aby stworzyć lub zaksięgować nowy!'"));
				EndIf;	
			EndIf;
		Else
			// BO is found, open it
			Selection = QueryResult.Select();
			Selection.Next();
			Selection.BookkeepingOperation.GetObject().GetForm("DocumentForm").Open();
		EndIf;	
				
	EndIf;
	
	
EndProcedure

Function GetRowGrossAmount(Amount, VAT, AmountType) Export 
	
	Return Amount + ?(AmountType = Enums.NetGross.Gross, 0, VAT);
	
EndFunction // GetRowGrossAmount()

Procedure SetVATControlsEnabled(DocumentForm,ColumnsArray,Enable = Undefined) Export
	
	VATCalculationMethod = DocumentsPostingAndNumbering.GetVATCalculationMethod(DocumentForm.Date, DocumentForm.Company);
	
	If Enable = Undefined Then 
		
		ControlsEnable = True;
		
		If VATCalculationMethod = Enums.VATCalculationMethod.ByEachDocumentLine Then
			
			ControlsEnable = True;
			
		ElsIf VATCalculationMethod = Enums.VATCalculationMethod.ByFullDocumentAmount Then
			
			ControlsEnable = False;
			
		EndIf;
		
	Else
		
		ControlsEnable = Enable;
		
	EndIf;
	
	For Each Control In ColumnsArray Do
		Control.ReadOnly = NOT ControlsEnable;
	EndDo;	
	
EndProcedure	

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR HANDLING TYPING ON A CONTROL

// Function creates a selection list for the TextEditEnd event.
//
// Parameters:
// QueryResult - QueryResult on typing
// Text - String - typing text
// CatalogType - Type - type of the Autocomplete catalog
//
// Returns:
// ValueList
//
Function GetTypingChoiceList(QueryResult, Val Text, CatalogType)

	EmptyRef = New(CatalogType);
	SearchValueByStringCollection = EmptyRef.Metadata().InputByString;
	
	ValueListReturn = New ValueList;
	
	Text = Upper(Text);
	TextLength = StrLen(Text);
	
	QueryTable = QueryResult.Unload();
	
	IsDescription = (QueryTable.Columns.Find("Description") <> Undefined);
	IsCode          = (QueryTable.Columns.Find("Code") <> Undefined);
	
	For each TableRow In QueryTable Do
	
		If IsDescription AND SearchValueByStringCollection.Find("Description") <> Undefined AND Upper(Left(TableRow.Description, TextLength)) = Text Then
			ValueListReturn.Add(TableRow.Ref, (TableRow.Description + ?(IsCode, (" (" + TrimAll(String(TableRow.Code)) + ")"), "")));
			Continue; 
		EndIf;
		
		If IsCode AND SearchValueByStringCollection.Find("Code") <> Undefined AND Upper(Left(TableRow.Code, TextLength)) = Text Then
			If IsDescription Then
				ValueListReturn.Add(TableRow.Ref, (TableRow.Description + " (" + TrimAll(String(TableRow.Code)) + ")"));
			Else
				ValueListReturn.Add(TableRow.Ref, String(TableRow.Code));
			EndIf; 
			Continue;
		EndIf;
		
		For each Column In QueryTable.Columns Do
		
			If Column.Name = "Description" OR Column.Name = "Code" OR Column.Name = "Ref" Then
				Continue;
			EndIf; 
		
			If Upper(Left(TableRow[Column.Name], TextLength)) = Text Then
				ValueListReturn.Add(TableRow.Ref, (TableRow[Column.Name] + ?(IsDescription, (" (" + String(TableRow.Description) + ")"), "")));
			EndIf
			
		EndDo; 
	
	EndDo; 

	Return ValueListReturn;
	
EndFunction

// Procedure serves the RefreshDisplay event on the form which contains typing control.
//
// Parameters:
// ThisForm - ContactInformation data register record form
// Control - control in which typing is performed
//
Procedure RefreshDisplayOnTyping(ThisForm, Control, ProcessingTyping, TextTyping) Export

	If ProcessingTyping Then
		ThisForm.CurrentControl = Control;
		Control.SelectedText = TextTyping;
		ProcessingTyping = False;
		TextTyping = "";
	EndIf; 
	
	If TypeOf(Control.Value) = Type("String") Then
		Control.FieldTextColor = StyleColors.InformationTextColor;
	Else
		Control.FieldTextColor = New Color;
	EndIf;

EndProcedure

// Function serves the TextEditEnd event of the Profile control on the ContactInformation 
// data register record form.
//
// Parameters:
// Control - edit control
// Text - text entered in the Profile edit field
// Value - edit control data
// StandardProcessing - Boolean - standard handling of the autocomplete event
// ParametersStructure - structured query parameters, key - parameter name, value - parameter value.
// ThisForm - ContactInformation data register record form
// CatalogType - Type - type of the Autocomplete catalog
// CanBeCreatedNew - Boolean, defines that new value maybe added, and shows corresponding item in list
// Return value  - True if new value should be created, False if no value should be created
Function TextEditEndInControl(Control, Text, Value, StandardProcessing, ParametersStructure, ThisForm, CatalogType, ProcessingTyping = Undefined, TextTyping = Undefined, LastControlValueTyping = Undefined, GetDefaultTextIfEmptyValue = True, CanBeCreatedNew = False) Export

	If IsBlankString(Text) Then
		Value = New(CatalogType);
		StandardProcessing = False;
		Return False;
	EndIf; 

	QueryResult = GetAutoCompleteQueryResult(Text, ParametersStructure, CatalogType, 51);
	
	If QueryResult = Undefined Then
		Return False;
	EndIf; 
	
	StandardProcessing = False;
	
	If QueryResult.IsEmpty() AND GetDefaultTextIfEmptyValue Then
		Value = Text;
	Else
		Selection = QueryResult.Select();
		If Selection.Count() = 1 Then
			Selection.Next();
			Value = Selection.Ref;
		ElsIf Selection.Count() > 50 Then
			ShowMessageBox(, NStr("en='Found more than 50 items conforming selection options. Specify a longer string or use the Select command (F4)';pl='Znaleziono ponad 50 pozycji spełniających kryteria wyboru. Wpisz dłuższy ciąg znaków lub użyj polecenia Wybierz (F4)'"));
			If LastControlValueTyping = Undefined Then
				Value = Text;
			Else
				Value = LastControlValueTyping;
			EndIf; 
		Else
			UniqueKey = New UUID;
			If Selection.Count() = 0 Then
				SelectedItem = Undefined;
			Else
				ChoiceList = GetTypingChoiceList(QueryResult, Text, CatalogType);
				If CanBeCreatedNew Then
					ChoiceList.Insert(0,UniqueKey,Nstr("en='<Add new>';pl='<Dodaj nowy>'"));
				EndIf;	
				SelectedItem = ThisForm.ChooseFromList(ChoiceList, Control);
			EndIf; 
			If SelectedItem = Undefined Then
				AnswerToQuestion = DoQueryBox(Nstr("en = 'Invalid data in control.';pl='Niepoprawne dane w kontrolce.'") + Chars.LF + Nstr("en='Continue?';pl='Kontyunować?'"), QuestionDialogMode.YesNo, , DialogReturnCode.No);
				If LastControlValueTyping = Undefined Then
					Value = Text;
				Else
					Value = LastControlValueTyping;
				EndIf; 
				If AnswerToQuestion <> DialogReturnCode.Yes Then
					ProcessingTyping = True;
					TextTyping = Text;
				EndIf;
			Else
				If SelectedItem.Value = UniqueKey Then 
					Return True;
				Else	
					Value = SelectedItem.Value;
				EndIf;	
			EndIf; 
		EndIf; 
	EndIf;
	
	Return False;

EndFunction

// Procedure serves the AutoCompleteText event of the TextBox control for substitution of the text autocomplete results.
//
// Parameters:
// Control - edit control
// Text - text entered in the Profile edit field
// AutoCompleteText - autocomplete text for the View field
// StandardProcessing - Boolean - standard handling of the autocomplete event
// ParametersStructure - structured query parameters, key - parameter name, value - parameter value.
// CatalogType - Type - type of the Autocomplete catalog
//
Procedure AutoCompleteTextInControl(Control, Text, AutoCompleteText, StandardProcessing, ParametersStructure, CatalogType) Export

	QueryResult = GetAutoCompleteQueryResult(Text, ParametersStructure, CatalogType, 2);
	
	If QueryResult = Undefined Then
		Return;
	EndIf; 
	
	StandardProcessing = False;
	
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		If Selection.Count() = 1 Then
			Selection.Next();
			EmptyRef = New(CatalogType);
			SearchItemCollection = EmptyRef.Metadata().InputByString;
			For each  CollectionItem In SearchItemCollection Do
				If Left(Upper(Selection[CollectionItem.Name]), StrLen(Text)) = Upper(Text) Then
					If Upper(Text) <> Upper(Selection[CollectionItem.Name]) Then
						AutoCompleteText = Selection[CollectionItem.Name];
					EndIf;
					Break;
				EndIf; 
			EndDo; 
		EndIf; 
	EndIf;

EndProcedure

// Function executes query on text autocomplete and on the end of text entry in the edit control.
//
// Parameters:
// Text - String - text entered in the Profile edit field on the ContactInformatio form, by which query is created
// ParametersStructure - structured query parameters, key - parameter name, value - parameter value.
// CatalogType - Type - type of the Autocomplete catalog
// CountOfElement - Number - number of elements in the query result table
//
// Returns:
// QueryResult
//
Function GetAutoCompleteQueryResult(Val Text, ParametersStructure, ObjectType, CountOfElement) Export

	TypeEmptyRef = New(ObjectType);
	
	// document or catalog
	IsCatalogRef = Catalogs.AllRefsType().ContainsType(ObjectType);
	
	SearchByStringCollection = TypeEmptyRef.Metadata().InputByString;
	If SearchByStringCollection.Count() = 0 Then
		Return Undefined;
	EndIf; 
	
	ObjectTableName = ?(IsCatalogRef, "Catalog.", "Document.") + TypeEmptyRef.Metadata().Name;
	
	Query = New Query;
	
	Text = StrReplace(Text, "~", "~~");
	Text = StrReplace(Text, "%", "~%");
	Text = StrReplace(Text, "_", "~_");
	Text = StrReplace(Text, "[", "~[");
	Text = StrReplace(Text, "-", "~-");
	Query.SetParameter("AutoCompleteText", (Text + "%"));
	
	FilterByStructureString = "";
	For Each StructureElement In ParametersStructure Do
		Query.SetParameter(StructureElement.Key, StructureElement.Value);
		FilterByStructureString = FilterByStructureString + "
		|		AND
		|		" + ?(SearchByStringCollection.Count() = 1, "NestedSelectTable.", "ObjectTable.") + StructureElement.Key + " = &"+ StructureElement.Key;
	EndDo; 
	
	FieldsString = "
	|SELECT ALLOWED DISTINCT TOP " + String(CountOfElement) + "
	|	NestedSelectTable.Ref AS Ref,
	|";
	
	If IsCatalogRef Then
		If TypeEmptyRef.Metadata().DescriptionLength > 0 Then
			FieldsString = FieldsString + "
			|	NestedSelectTable.Ref.Description AS Description,";
		EndIf;
		
		If TypeEmptyRef.Metadata().CodeLength > 0 Then
			FieldsString = FieldsString + "
			|	NestedSelectTable.Ref.Code AS Code,";
		EndIf; 
	EndIf;
	
	If SearchByStringCollection.Count() = 1 Then
		
		CollectionItem = SearchByStringCollection[0];
		
		If CollectionItem.Name <> "Description" AND CollectionItem.Name <> "Code" Then
			FieldsString = FieldsString + "
			|	NestedSelectTable.Ref." + CollectionItem.Name + " AS " + CollectionItem.Name;
		EndIf;
		
		Query.Text = Left(FieldsString, (StrLen(FieldsString) - 1)) + "
		|FROM
		|	" + ObjectTableName + " AS NestedSelectTable
		|WHERE
		|	NestedSelectTable." + CollectionItem.Name + " LIKE &AutoCompleteText ESCAPE ""~""" + FilterByStructureString;
	
	Else
		
		FirstElement = True;
		TablesString = "";
		For each  CollectionItem In SearchByStringCollection Do
			
			If CollectionItem.Name <> "Description" AND CollectionItem.Name <> "Code" Then
				FieldsString = FieldsString + "
				|	NestedSelectTable.Ref." + CollectionItem.Name + " AS " + CollectionItem.Name + ",";
			EndIf;
			
			If NOT FirstElement Then
				TablesString = TablesString + "
				|	UNION ALL
				|";
			EndIf; 
			FirstElement = False;
			
			TablesString = TablesString + "
			|	SELECT
			|		ObjectTable.Ref AS Ref
			|	FROM
			|		" + ObjectTableName + " AS ObjectTable
			|	WHERE
			|		ObjectTable." + CollectionItem.Name + " LIKE &AutoCompleteText ESCAPE ""~""" + FilterByStructureString;
		
		EndDo; 
		
		Query.Text = Left(FieldsString, (StrLen(FieldsString) - 1)) + "
		|FROM
		|
		|	(
		|" + TablesString + "
		|	) AS NestedSelectTable";
	
	EndIf; 
	
	Return Query.Execute();

EndFunction

Procedure ShowSlaveDocuments(DocumentRef) Export 
	
	Form = GetCommonForm("SlaveDocuments");
	If Form.IsOpen() Then
		Form.Close();
	EndIf;
	Form.DocumentRef = DocumentRef;
	Form.Open();
	
EndProcedure

Procedure ShowDocumentsRecordsBookkeeping(DocumentRef) Export
	
	// if Ref doesn't exists - should be created
	If NOT ValueIsFilled(DocumentRef) Then
		ShowMessageBox(, NStr("en='Document should be written!';pl='Dokument powinien być zapisany!'"));
		Return;
	EndIf;
	
	DocumentsRecords = DataProcessors.PrintoutDocumentsBookkeepingRecords.Create();
	
	DocumentsRecords.Document = DocumentRef;
	
	DocumentsRecords.GenerateReport();
	
EndProcedure // ShowDocumentsRecords


Procedure SetVATNumberMask(LocationType, VATNumber, ControlVATNumber) Export
	
	If LocationType = Enums.BusinessPartnersLocationTypes.Domestic Then
		ControlVATNumber.Mask = "9999999999";
	ElsIf LocationType = Enums.BusinessPartnersLocationTypes.EuropeanUnion Then
		ControlVATNumber.Mask = "UUUX99999UUU99";
	ElsIf LocationType = Enums.BusinessPartnersLocationTypes.Foreign Then
		ControlVATNumber.Mask = "";
	Else
		ControlVATNumber.Mask = "";
		ControlVATNumber.Value = VATNumber;
	EndIf;
	
	If TrimAll(VATNumber) <> TrimAll(ControlVATNumber.Value) Then
		VATNumber = ControlVATNumber.Value
	EndIf;
	
EndProcedure

Procedure ShowRegistersRecords(FormOwner,ObjectRef) Export
	
	RecordsReportAndCorrectionForm = DataProcessors.RecordsReportAndCorrection.GetForm("MainForm", FormOwner, FormOwner);
	If ValueIsFilled(ObjectRef) Then
		RecordsReportAndCorrectionForm.Document = ObjectRef;
	EndIf;
	RecordsReportAndCorrectionForm.Open();
	
EndProcedure


Procedure ShowDocumentAcceptanceForm(Form) Export
	
	If Not WriteObjectInForm(Form, Form.Modified) Then
		Return;
	EndIf;
	
	AcceptanceForm = DataProcessors.DocumentsAcceptance.GetForm("DocumentForm", Form);
	AcceptanceForm.Document = Form.Ref;
	AcceptanceForm.Open();
	
EndProcedure

Procedure AdjustFormActionsAcceptanceButton(Form) Export
	
	Button = Form.Controls.FormActions.Buttons.Acceptance;
	
	If Form.IsNew() Then
		
		Enabled = False;
		Picture = New Picture;
		
	Else
		
		CurrentStateStructure = DocumentsAcceptance.GetCurrentState(Form.Ref);
		
		If CurrentStateStructure = Undefined Or ValueIsNotFilled(CurrentStateStructure.Schema) Then
			
			Enabled = False;
			Picture = New Picture;
			
		Else
			
			Enabled = True;
			
			If ValueIsFilled(CurrentStateStructure.NextUser) Then
				Picture = New Picture;
			Else
				Picture = PictureLib.Accepted;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Button.Enabled = Enabled;
	Button.Picture = Picture;
	
EndProcedure

Procedure SetPanelFirstVisiblePage(PanelControl) Export
	
	For Each PanelPage In PanelControl.Pages Do
		If PanelPage.Visible Then
			PanelControl.CurrentPage = PanelPage;
			Return;
		EndIf;	
	EndDo;	
	
EndProcedure	

////////////////////////////////////////////////////////////////////////////////
// DOCUMENT POSTING QUERY

Function FillIsModifiedField(ThisForm, WriteMode, IsModified) Export
	
	If WriteMode = DocumentWriteMode.UndoPosting Then
		
		Return Undefined;
		
	ElsIf IsModified <> Undefined Then
		
		Return IsModified;
		
	ElsIf IsModified = Undefined And ThisForm.Modified Then
		
		Return True;
		
	Else
		
		Return Undefined;
		
	EndIf;
	
EndFunction

Function CheckDocumentModificate(Object, ThisForm, IsModified) Export
	
	If Not CommonAtServer.GetUserSettingsValue("TheUserKnowsPrinciplesOfPosting") Then  // environment option
		
		If Not Object.Posted And Not ThisForm.ReadOnly And Not ThisForm.DeletionMark Then //form is unlock for operation (documetn option)
			
			If Not ThisForm.Modified And IsModified = Undefined Then
				
				Return False;
				
			EndIf;
			
			//Do Query Dialog
			DocumentSavingAndPostingQueryForm = GetCommonForm("DocumentClosingForm");
			RewriteMode = DocumentSavingAndPostingQueryForm.DoModal();
			
			If RewriteMode = DialogReturnCode.No Then
				
				Return False;
				
			ElsIf RewriteMode = DialogReturnCode.Yes Then
				
				Return True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
/// Document code column

Function GetCurrentUserCodeType() Export
	
	Return CommonAtServer.GetUserSettingsValue(ChartsOfCharacteristicTypes.UserSettings.ShowItemCodeInDocument,SessionParameters.CurrentUser);
	
EndFunction	

Procedure AddDocumentTabularPartCodeColumn(TableBoxControl,ItemColumnName = "Item",CodeType = Undefined) Export
	
	If CodeType = Undefined Then
		CodeType = CommonAtServer.GetUserSettingsValue(ChartsOfCharacteristicTypes.UserSettings.ShowItemCodeInDocument,SessionParameters.CurrentUser);
	EndIf;	
	
	If ValueIsFilled(CodeType) AND CodeType <> Enums.CodeTypes.DontShow Then
		
		FoundItemColumn = TableBoxControl.Columns.Find(ItemColumnName);
		If FoundItemColumn <> Undefined Then
			
			CodeColumn = TableBoxControl.Columns.Insert(TableBoxControl.Columns.IndexOf(FoundItemColumn)+1,Metadata.Enums.CodeTypes.EnumValues[CommonAtServer.GetEnumNameByValue(CodeType)].Synonym);
			CodeColumn.Name = "GeneratedCodeColumn";
			CodeColumn.ReadOnly = True;
			CodeColumn.Visible = True;
			CodeColumn.SetControl(Type("TextBox"));
			
		EndIf;	
		
	EndIf;	
	
EndProcedure	

Procedure ShowDocumentCodeColumn(RowAppearance, RowData, ItemColumnName = "Item", CodeType = Undefined) Export
	
	If CodeType = Undefined Then
		CodeType = CommonAtServer.GetUserSettingsValue(ChartsOfCharacteristicTypes.UserSettings.ShowItemCodeInDocument,SessionParameters.CurrentUser);
	EndIf;	
	
	If CodeType = Enums.CodeTypes.Code Then
		RowAppearance.Cells.GeneratedCodeColumn.Text = TrimAll(RowData[ItemColumnName].Code);	
	ElsIf CodeType = Enums.CodeTypes.Article Then
		RowAppearance.Cells.GeneratedCodeColumn.Text = TrimAll(RowData[ItemColumnName].Article);	 	
	ElsIf CodeType = Enums.CodeTypes.EANCode Then
		RowAppearance.Cells.GeneratedCodeColumn.Text = TrimAll(RowData[ItemColumnName].MainBarCode);
	Else
		Return;
	EndIf;
	RowAppearance.Cells.GeneratedCodeColumn.ShowText = True;
	
EndProcedure	
