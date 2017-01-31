//////////////////////////////////////////////////////////////////////////////// 
// EXPORT PROCEDURES AND FUNCTIONS 

// Displays a message on filling error.
//
Procedure ShowMessageAboutError(ErrorObject, MessageText, TabularSectionName = Undefined, LineNumber = Undefined, Field = Undefined, Cancel = False) Export
	
	Message = New UserMessage();
	Message.Text = MessageText;
	
	If TabularSectionName <> Undefined Then
		Message.Field = TabularSectionName + "[" + (LineNumber - 1) + "]." + Field;
	ElsIf ValueIsFilled(Field) Then
		Message.Field = Field;
	EndIf;
	
	If ErrorObject <> Undefined Then
		Message.SetData(ErrorObject);
	EndIf;
	
	Message.Message();
	
	Cancel = True;
	
EndProcedure // MessageAboutError()

// Function checks whether it is possible to print receipt on fiscal data recorder.
//
// Parameters:
// Form - ManagedForm - Document form
//
// Returns:
// Boolean - Shows that printing is possible
//
Function CheckPossibilityOfReceiptPrinting(Form, ShowMessageBox = False) Export
	
	CheckPrint = True;
	
	// If object is not posted or modified - execute posting.
	If Not Form.Object.Posted
		OR Form.Modified Then
		
		Try
			If Not Form.Write(New Structure("WriteMode", DocumentWriteMode.Posting)) Then
				CheckPrint = False;
			EndIf;
		Except
			ShowMessageBox = True;
			CheckPrint = False;
		EndTry;
			
	EndIf;
	
	Return CheckPrint;

EndFunction // CheckReceiptPrintingPossibility()

//////////////////////////////////////////////////////////////////////////////// 
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Function recalculates the amount from one currency to another
//
// Parameters:      
// Amount         - Number - amount that should be recalculated.
// 	InitRate       - Number - currency rate from which you should recalculate.
// 	FinRate       - Number - currency rate to which you should recalculate.
// 	RepetitionBeg  - Number - multiplicity from which you
// should recalculate (by default = 1).
// 	RepetitionEnd  - Number - multiplicity in which
// it is required to recalculate (by default =1)
//
// Returns: 
//  Number - amount recalculated to another currency.
//
Function RecalculateFromCurrencyToCurrency(Amount, InitRate, FinRate,	RepetitionBeg = 1, RepetitionEnd = 1) Export
	
	If (InitRate = FinRate) AND (RepetitionBeg = RepetitionEnd) Then
		Return Amount;
	EndIf;
	
	If InitRate = 0 OR FinRate = 0 OR RepetitionBeg = 0 OR RepetitionEnd = 0 Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Null exchange rate has been found. Recalculation isn't executed.'");
		Message.Message();
		Return Amount;
	EndIf;
	
	RecalculatedSumm = Round((Amount * InitRate * RepetitionEnd) / (FinRate * RepetitionBeg), 2);
	
	Return RecalculatedSumm;
	
EndFunction // RecalculateFromCurrencyToCurrency()

// Procedure updates document state.
//
Procedure RefreshDocumentStatus(Object, DocumentStatus, PictureDocumentStatus, PostingIsAllowed) Export
	
	If Object.Posted Then
		DocumentStatus = "Posted";
		PictureDocumentStatus = 1;
	ElsIf PostingIsAllowed Then
		DocumentStatus = "Not posted";
		PictureDocumentStatus = 0;
	Else
		DocumentStatus = "Recorded";
		PictureDocumentStatus = 3;
	EndIf;
	
EndProcedure // UpdateDocumentState()

// Function returns weekday presentation.
//
Function GetPresentationOfWeekDay(CalendarWeekDay) Export
	
	WeekDayNumber = WeekDay(CalendarWeekDay);
	If WeekDayNumber = 1 Then
		
		Return NStr("en='Mo';ru='Пн'");
		
	ElsIf WeekDayNumber = 2 Then
		
		Return NStr("en='Tu';ru='Вт'");
		
	ElsIf WeekDayNumber = 3 Then
		
		Return NStr("en='We';ru='Ср'");
		
	ElsIf WeekDayNumber = 4 Then
		
		Return NStr("en='Th';ru='Чт'");
		
	ElsIf WeekDayNumber = 5 Then
		
		Return NStr("en='Fr';ru='Пт'");
		
	ElsIf WeekDayNumber = 6 Then
		
		Return NStr("en='Sa';ru='Sa'");
		
	Else
		
		Return NStr("en='Su';ru='Вс'");
		
	EndIf;
	
EndFunction // GetWeekDayPresentation()

// Fills in data structure for opening calendar selection form
//
Function GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen, 
		CloseOnChoice = True, 
		Multiselect = False) Export
	
	ParametersStructure = New Structure;
	
	ParametersStructure.Insert(
		"CalendarDate", 
			CalendarDateOnOpen
		);
		
	ParametersStructure.Insert(
		"CloseOnChoice", 
			CloseOnChoice
		);
		
	ParametersStructure.Insert(
		"Multiselect", 
			Multiselect
		);
		
	Return ParametersStructure;
	
EndFunction // GetCalendarGenerateFormOpeningParameters()

// Places passed value to ValuesList
// 
Function ValueToValuesListAtClient(Value, ValueList = Undefined, AddDuplicates = False) Export
	
	If TypeOf(ValueList) = Type("ValueList") Then
		
		If AddDuplicates Then
			
			ValueList.Add(Value);
			
		ElsIf ValueList.FindByValue(Value) = Undefined Then
			
			ValueList.Add(Value);
			
		EndIf;
		
	Else
		
		ValueList = New ValueList;
		ValueList.Add(Value);
		
	EndIf;
	
	Return ValueList;
	
EndFunction // ValueToValuesListOnClient()

// Fills in the values list Receiver from the values list Source
//
Procedure FillListByList(Source,Receiver) Export

	Receiver.Clear();
	For Each ListIt IN Source Do
		Receiver.Add(ListIt.Value, ListIt.Presentation);
	EndDo;

EndProcedure

//////////////////////////////////////////////////////////////////////////////// 
// PROCEDURES FOR WORK WITH SUBORDINATE TABULAR SECTIONS

// Procedure adds connection key to tabular section.
//
// Parameters:
//  DocumentForm - ManagedForm, contains a
//                 document form attributes of which are processed by the procedure
//
Procedure AddConnectionKeyToTabularSectionLine(DocumentForm) Export

	TabularSectionRow = DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData;
    
	TabularSectionRow.ConnectionKey = CreateNewLinkKey(DocumentForm);		
        
EndProcedure // AddConnectionKeyToTabularSectionRow()

// Procedure adds connection key to the subordinate tabular section.
//
// Parameters:
//  DocumentForm - ManagedForm contains a
//                 document form attributes
// of which are processed by the SubordinateTabularSectionName procedure - String that contains the
//                 subordinate tabular section name.
//
Procedure AddConnectionKeyToSubordinateTabularSectionLine(DocumentForm, SubordinateTabularSectionName) Export
	
	SubordinateTbularSection = DocumentForm.Items[SubordinateTabularSectionName];
	
	StringSubordinateTabularSection = SubordinateTbularSection.CurrentData;
	StringSubordinateTabularSection.ConnectionKey = SubordinateTbularSection.RowFilter["ConnectionKey"];
	
	FilterStr = New FixedStructure("ConnectionKey", SubordinateTbularSection.RowFilter["ConnectionKey"]);
	DocumentForm.Items[SubordinateTabularSectionName].RowFilter = FilterStr;

EndProcedure // AddConnectionKeyToSubordinateTabularSectionRow()

// Procedure prohibits to add new row if row in the main tabular section is not selected.
//
// Parameters:
//  DocumentForm - ManagedForm contains a
//                 document form attributes
// of which are processed by the SubordinateTabularSectionName procedure - String that contains the
//                 subordinate tabular section name.
//
Function BeforeAddToSubordinateTabularSection(DocumentForm, SubordinateTabularSectionName) Export

	If DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData = Undefined Then
		Message = New UserMessage;
		Message.Text = NStr("en='Main tabular section row is not selected.';ru='Не выбрана строка основной табличной части!'");
		Message.Message();
		Return True;
	Else
		Return False;
	EndIf;
		
EndFunction // BeforeStartAddingToSubordinateTabularSection()

// Procedure deletes rows from the subordinate tabular section.
//
// Parameters:
//  DocumentForm - ManagedForm contains a
//                 document form attributes
// of which are processed by the SubordinateTabularSectionName procedure - String that contains the
//                 subordinate tabular section name.
//
Procedure DeleteRowsOfSubordinateTabularSection(DocumentForm, SubordinateTabularSectionName) Export

	TabularSectionRow = DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData;
	SubordinateTbularSection = DocumentForm.Object[SubordinateTabularSectionName];
   	
    SearchResult = SubordinateTbularSection.FindRows(New Structure("ConnectionKey", TabularSectionRow.ConnectionKey));
	For Each SearchString IN  SearchResult Do
		IndexOfDeletion = SubordinateTbularSection.IndexOf(SearchString);
		SubordinateTbularSection.Delete(IndexOfDeletion);
	EndDo;
	
EndProcedure // DeleteSubordinateTabularSectionRows()

// Procedure creates a new key of links for tables.
//
// Parameters:
//  DocumentForm - ManagedForm, contains a
//                 document form whose attributes are processed by the procedure.
//
Function CreateNewLinkKey(DocumentForm) Export

	ValueList = New ValueList;
	
	TabularSection = DocumentForm.Object[DocumentForm.TabularSectionName];
	For Each TSRow IN TabularSection Do
        ValueList.Add(TSRow.ConnectionKey);
	EndDo;

    If ValueList.Count() = 0 Then
		ConnectionKey = 1;
	Else
		ValueList.SortByValue();
		ConnectionKey = ValueList.Get(ValueList.Count() - 1).Value + 1;
	EndIf;

	Return ConnectionKey;

EndFunction //  CreateNewLinkKey()

// Procedure sets the filter on a subordinate tabular section.
//
Procedure SetFilterOnSubordinateTabularSection(DocumentForm, SubordinateTabularSectionName) Export
	
	TabularSectionRow = DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData;
	If TabularSectionRow = Undefined Then
		Return;
	EndIf; 
	
	FilterStr = New FixedStructure("ConnectionKey", DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData.ConnectionKey);
	DocumentForm.Items[SubordinateTabularSectionName].RowFilter = FilterStr;
	
EndProcedure //SetFilterOnSubordinateTabularSection()

//////////////////////////////////////////////////////////////////////////////// 
// PROCEDURES AND FUNCTIONS OF LIST FORM AND COUNTERPARTIES CATALOG SELECTION

// Function checks whether positioning on the row activation is correct.
//
Function PositioningIsCorrect(Form) Export
	
	TypeGroup = Type("DynamicalListGroupRow");
		
	If TypeOf(Form.Items.List.CurrentRow) <> TypeGroup AND ValueIsFilled(Form.Items.List.CurrentRow) Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction // PositioningIsCorrect()

// Fills in the footer label: Selection basis of the Counterparties catalog.
//
Procedure FillBasisRow(Form) Export
	
	Basis = Form.Bases.FindRows(New Structure("Counterparty", Form.Items.List.CurrentRow));
	If Basis.Count() = 0 Then
		Form.ChoiceBasis = "";
	Else
		Form.ChoiceBasis = Basis[0].Basis;
	EndIf;
	
EndProcedure // FillBasisRow()

// Procedure restores list display after a fulltext search.
//
Procedure RecoverListDisplayingAfterFulltextSearch(Form) Export
	
	If String(Form.Items.List.Representation) <> Form.ViewModeBeforeFulltextSearchApplying Then
		If Form.ViewModeBeforeFulltextSearchApplying = "Hierarchical list" Then
			Form.Items.List.Representation = TableRepresentation.HierarchicalList;
		ElsIf Form.ViewModeBeforeFulltextSearchApplying = "Tree" Then
			Form.Items.List.Representation = TableRepresentation.Tree;
		EndIf;
	EndIf;
	
EndProcedure // RecoverListDisplayingAfterFulltextSearch()

//////////////////////////////////////////////////////////////////////////////// 
// LIST FORMS PROCEDURES (INFORMATION PANEL)

// Processes a row activation event of the document list.
//
Procedure InfoPanelProcessListRowActivation(Form, InfPanelParameters) Export
	
	CurrentDataOfList = Form.Items.List.CurrentData;
	
	If CurrentDataOfList <> Undefined
		AND CurrentDataOfList.Property(InfPanelParameters.CIAttribute) Then
		
		CICurrentAttribute = CurrentDataOfList[InfPanelParameters.CIAttribute];
		
		If Form.ReferenceInformation <> CICurrentAttribute Then
			
			If ValueIsFilled(CICurrentAttribute) Then
				
				IPData = SmallBusinessServer.InfoPanelGetData(CICurrentAttribute, InfPanelParameters);
				InfoPanelFill(Form, InfPanelParameters, IPData);
				
				Form.ReferenceInformation = CICurrentAttribute;
				
			Else
				
				InfoPanelFill(Form, InfPanelParameters);
				
			EndIf;
			
		EndIf;
		
	Else
		
		InfoPanelFill(Form, InfPanelParameters);
		
	EndIf;
	
EndProcedure // InfoPanelProcessListRowActivation()

// Procedure fills in data of the list info panel.
//
Procedure InfoPanelFill(Form, InfPanelParameters, IPData = Undefined)
	
	If IPData = Undefined Then
	
		Form.ReferenceInformation = Undefined;
		
		// Counterparties contact information.
		If InfPanelParameters.Property("Counterparty") Then
			
			Form.CounterpartyPhoneInformation = "";
			Form.CounterpartyInformationES = "";
			Form.CounterpartyFaxInformation = "";
			
			Form.CounterpartyFactAddressInformation = "";
			If Form.Items.Find("InformationCounterpartyShippingAddress") <> Undefined
				OR Form.Items.Find("DetailsListCounterpartyShippingAddress") <> Undefined Then
				
				Form.InformationCounterpartyShippingAddress = "";
				
			EndIf;
			Form.CounterpartyLegalAddressInformation = "";
			
			Form.InformationCounterpartyPostalAddress = "";
			Form.InformationCounterpartyAnotherInformation = "";
			
			// MutualSettlements.
			If InfPanelParameters.Property("MutualSettlements") Then
				
				Form.CounterpartyDebtInformation = 0;
				Form.OurDebtInformation = 0;
				
			EndIf;
			
		EndIf;
		
		// Contacts contact information.
		If InfPanelParameters.Property("ContactPerson") Then
			
			Form.InformationContactPhone = "";
			Form.ContactPersonESInformation = "";
			
		EndIf;
		
	Else
		
		// Counterparties contact information.
		If InfPanelParameters.Property("Counterparty") Then
			
			Form.CounterpartyPhoneInformation 	= IPData.Phone;
			Form.CounterpartyInformationES 		= IPData.E_mail;
			Form.CounterpartyFaxInformation 		= IPData.Fax;
			
			Form.CounterpartyFactAddressInformation = IPData.RealAddress;
			If Form.Items.Find("InformationCounterpartyShippingAddress") <> Undefined
				OR Form.Items.Find("DetailsListCounterpartyShippingAddress") <> Undefined Then
				
				Form.InformationCounterpartyShippingAddress = IPData.ShippingAddress;
				
			EndIf;
			Form.CounterpartyLegalAddressInformation 	= IPData.LegAddress;
			
			Form.InformationCounterpartyPostalAddress 	= IPData.MailAddress;
			Form.InformationCounterpartyAnotherInformation 	= IPData.OtherInformation;
			
			// MutualSettlements.
			If InfPanelParameters.Property("MutualSettlements") Then
				
				Form.CounterpartyDebtInformation = IPData.Debt;
				Form.OurDebtInformation 		= IPData.OurDebt;
				
			EndIf;
			
		EndIf;
		
		// Contacts contact information.
		If InfPanelParameters.Property("ContactPerson") Then
			
			Form.InformationContactPhone 	= IPData.CLPhone;
			Form.ContactPersonESInformation 		= IPData.ClEmail;
			
		EndIf;
		
	EndIf;
	
EndProcedure // InfoPanelFill()

#Region DiscountCards

// Processes a row activation event of the document list.
//
Procedure DiscountCardsInformationPanelHandleListRowActivation(Form, InfPanelParameters) Export
	
	CurrentDataOfList = Form.Items.List.CurrentData;
	
	If CurrentDataOfList <> Undefined
		AND CurrentDataOfList.Property(InfPanelParameters.CIAttribute) Then
		
		CICurrentAttribute = CurrentDataOfList[InfPanelParameters.CIAttribute];
		
		If Form.ReferenceInformation <> InfPanelParameters.DiscountCard Then
			
			If ValueIsFilled(InfPanelParameters.DiscountCard) Then
				
				IPData = SmallBusinessServer.InfoPanelGetData(CICurrentAttribute, InfPanelParameters);
				DiscountCardsInfoPanelFill(Form, InfPanelParameters, IPData);
				
				Form.ReferenceInformation = CICurrentAttribute;
				
			Else
				
				DiscountCardsInfoPanelFill(Form, InfPanelParameters);
				
			EndIf;
			
		EndIf;
		
	Else
		
		DiscountCardsInfoPanelFill(Form, InfPanelParameters);
		
	EndIf;
	
EndProcedure // InfoPanelProcessListRowActivation()

// Procedure fills in data of the list info panel.
//
Procedure DiscountCardsInfoPanelFill(Form, InfPanelParameters, IPData = Undefined)
	
	If IPData = Undefined Then
	
		Form.ReferenceInformation = Undefined;
		
		// Counterparties contact information.
		If InfPanelParameters.Property("Counterparty") Then
			
			Form.CounterpartyPhoneInformation = "";
			Form.CounterpartyInformationES = "";
			Form.InformationDiscountPercentOnDiscountCard = "";
			Form.InformationSalesAmountOnDiscountCard = "";
			
		EndIf;
		
	Else
		
		// Counterparties contact information.
		If InfPanelParameters.Property("Counterparty") Then
			
			Form.CounterpartyPhoneInformation 				= IPData.Phone;
			Form.CounterpartyInformationES 					= IPData.E_mail;
			Form.InformationDiscountPercentOnDiscountCard 	= IPData.DiscountPercentByDiscountCard;
			Form.InformationSalesAmountOnDiscountCard	= IPData.SalesAmountOnDiscountCard;
			
		EndIf;
		
	EndIf;
	
EndProcedure // InfoPanelFill()

#EndRegion

//////////////////////////////////////////////////////////////////////////////// 
// SSM SUBSYSTEMS PROCEDURES AND FUNCTIONS

// Procedure inputs default expenses invoice while selecting
// accruals in the document tabular section.
//
// Parameters:
//  DocumentForm - ManagedForm, contains a
//                 document form whose attributes are processed by the procedure.
//
Procedure PutExpensesGLAccountByDefault(DocumentForm, StructuralUnit = Undefined) Export
	
	DataCurrentRows = DocumentForm.Items.AccrualsDeductions.CurrentData;
	
	ParametersStructure = New Structure("GLExpenseAccount, TypeOfAccount");
	ParametersStructure.Insert("AccrualDeductionKind", DataCurrentRows.AccrualDeductionKind);
	ParametersStructure.Insert("StructuralUnit", StructuralUnit);
	
	If ValueIsFilled(DataCurrentRows.AccrualDeductionKind) Then
		
		SmallBusinessServer.GetAccrualKindGLExpenseAccount(ParametersStructure);
		DataCurrentRows.GLExpenseAccount = ParametersStructure.GLExpenseAccount;
		
	EndIf;
	
	If DataCurrentRows.Property("TypeOfAccount") Then
		
		DataCurrentRows.TypeOfAccount = ParametersStructure.TypeOfAccount;
		
	EndIf;
	
EndProcedure // SetExpensesInvoiceByDefault()

// Procedure sets the registration period to of the beginning of month.
// It also updates period label on form
Procedure OnChangeRegistrationPeriod(SentForm) Export
	
	If Find(SentForm.FormName, "DocumentJournal") > 0 
		OR Find(SentForm.FormName, "ReportForm") Then
		SentForm.RegistrationPeriod 				= BegOfMonth(SentForm.RegistrationPeriod);
		SentForm.RegistrationPeriodPresentation 	= Format(SentForm.RegistrationPeriod, "DF='MMMM yyyy'");
	ElsIf Find(SentForm.FormName, "ListForm") > 0 Then
		SentForm.FilterRegistrationPeriod 			= BegOfMonth(SentForm.FilterRegistrationPeriod);
		SentForm.RegistrationPeriodPresentation 	= Format(SentForm.FilterRegistrationPeriod, "DF='MMMM yyyy'");
	Else
		SentForm.Object.RegistrationPeriod 		= BegOfMonth(SentForm.Object.RegistrationPeriod);
		SentForm.RegistrationPeriodPresentation 	= Format(SentForm.Object.RegistrationPeriod, "DF='MMMM yyyy'");
	EndIf;
	
EndProcedure // OnChangeRegistrationPeriod()

// Procedure executes date increment by
// regulatory buttons Used in log and salary documents and wages Expense CA from
// petty cash, reports Payroll sheets Step equals to month
//
// Parameters:
// SentForm 	- form data of
// which is corrected Direction 		- increment value can be positive or negative
Procedure OnRegistrationPeriodRegulation(SentForm, Direction) Export
	
	If Find(SentForm.FormName, "DocumentJournal") > 0 
		OR Find(SentForm.FormName, "ReportForm") Then
		
		SentForm.RegistrationPeriod = ?(ValueIsFilled(SentForm.RegistrationPeriod), 
							AddMonth(SentForm.RegistrationPeriod, Direction),
							AddMonth(BegOfMonth(CurrentDate()), Direction));
		
	ElsIf Find(SentForm.FormName, "ListForm") > 0 Then
		
		SentForm.FilterRegistrationPeriod = ?(ValueIsFilled(SentForm.FilterRegistrationPeriod), 
							AddMonth(SentForm.FilterRegistrationPeriod, Direction),
							AddMonth(BegOfMonth(CurrentDate()), Direction));
		
	Else
		
		SentForm.Object.RegistrationPeriod = ?(ValueIsFilled(SentForm.Object.RegistrationPeriod), 
							AddMonth(SentForm.Object.RegistrationPeriod, Direction),
							AddMonth(BegOfMonth(CurrentDate()), Direction));
		
	EndIf;
	
EndProcedure // OnRegistrationPeriodRegulation()

//////////////////////////////////////////////////////////////////////////////// 
// PRICING SUBSYSTEM PROCEDURES AND FUNCTIONS

// Procedure calculates the amount of the tabular section while filling by "Prices and currency".
//
Procedure CalculateTabularSectionRowSUM(DocumentForm, TabularSectionRow)
	
	If TabularSectionRow.Property("Count") AND TabularSectionRow.Property("Price") Then
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	EndIf;
	
	If TabularSectionRow.Property("DiscountMarkupPercent") Then
		If TabularSectionRow.DiscountMarkupPercent = 100 Then
			TabularSectionRow.Amount = 0;
		ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
			TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
		EndIf;
	EndIf;	

	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
	If DocumentForm.Object.Property("AmountIncludesVAT") Then
		TabularSectionRow.VATAmount = ?(
			DocumentForm.Object.AmountIncludesVAT, 
			TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
			TabularSectionRow.Amount * VATRate / 100
		);
		TabularSectionRow.Total = TabularSectionRow.Amount + ?(DocumentForm.Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	Else
		TabularSectionRow.VATAmount = TabularSectionRow.Amount * VATRate / 100;
		TabularSectionRow.Total = TabularSectionRow.Amount + TabularSectionRow.VATAmount;
	EndIf;	
	
	// AutomaticDiscounts
	If TabularSectionRow.Property("AutomaticDiscountsPercent") Then
		TabularSectionRow.AutomaticDiscountsPercent = 0;
		TabularSectionRow.AutomaticDiscountAmount = 0;
	EndIf;
	If TabularSectionRow.Property("TotalDiscountAmountIsMoreThanAmount") Then
		TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure // CalculateTabularSectionRowAmount()	

// Recalculate prices by the AmountIncludesVAT check box of the tabular section after changes in form "Prices and currency".
//
// Parameters:
//  PreviousCurrency - CatalogRef.Currencies,
//                 contains reference to the previous currency.
//
Procedure RecalculateTabularSectionAmountByFlagAmountIncludesVAT(DocumentForm, TabularSectionName) Export
																	   
	For Each TabularSectionRow IN DocumentForm.Object[TabularSectionName] Do
		
		VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
		
		If TabularSectionRow.Property("Price") Then
			If DocumentForm.Object.AmountIncludesVAT Then
				TabularSectionRow.Price = (TabularSectionRow.Price * (100 + VATRate)) / 100;
			Else
				TabularSectionRow.Price = (TabularSectionRow.Price * 100) / (100 + VATRate);
			EndIf;
		EndIf;
		
		CalculateTabularSectionRowSUM(DocumentForm, TabularSectionRow);
		        
	EndDo;

EndProcedure // RecalculateTabularSectionAmountByCheckBoxAmountIncludesVAT()

// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
// 
Procedure RefillTabularSectionPricesByPriceKind(DocumentForm, TabularSectionName, RecalculateDiscounts = False) Export
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				DocumentForm.Object.Date);
	DataStructure.Insert("Company",				DocumentForm.SubsidiaryCompany);
	DataStructure.Insert("PriceKind",			DocumentForm.Object.PriceKind);
	DataStructure.Insert("DocumentCurrency",	DocumentForm.Object.DocumentCurrency);
	DataStructure.Insert("AmountIncludesVAT",	DocumentForm.Object.AmountIncludesVAT);
	
	If RecalculateDiscounts Then
		DataStructure.Insert("DiscountMarkupKind", DocumentForm.Object.DiscountMarkupKind);
		DataStructure.Insert("DiscountMarkupPercent", 0);
		If SmallBusinessServer.DocumentAttributeExistsOnLink("DiscountPercentByDiscountCard", DocumentForm.Object.Ref) Then
			DataStructure.Insert("DiscountPercentByDiscountCard", DocumentForm.Object.DiscountPercentByDiscountCard);		
		EndIf;
	EndIf;
	
	For Each TSRow IN DocumentForm.Object[TabularSectionName] Do
		
		TSRow.Price = 0;
		
		If Not ValueIsFilled(TSRow.ProductsAndServices) Then
			Continue;	
		EndIf; 
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("ProductsAndServices",		TSRow.ProductsAndServices);
		TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
		TabularSectionRow.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		TabularSectionRow.Insert("VATRate",			TSRow.VATRate);
		TabularSectionRow.Insert("Price",				0);
		
		DocumentTabularSection.Add(TabularSectionRow);
		
	EndDo;
		
	SmallBusinessServer.GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
		
	For Each TSRow IN DocumentTabularSection Do

		SearchStructure = New Structure;
		SearchStructure.Insert("ProductsAndServices",		TSRow.ProductsAndServices);
		SearchStructure.Insert("Characteristic",		TSRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		SearchStructure.Insert("VATRate",			TSRow.VATRate);
		
		SearchResult = DocumentForm.Object[TabularSectionName].FindRows(SearchStructure);
		
		For Each ResultRow IN SearchResult Do
			
			ResultRow.Price = TSRow.Price;
			CalculateTabularSectionRowSUM(DocumentForm, ResultRow);
			
		EndDo;
		
	EndDo;
	
	If RecalculateDiscounts Then
		For Each TabularSectionRow IN DocumentForm.Object[TabularSectionName] Do
			TabularSectionRow.DiscountMarkupPercent = DataStructure.DiscountMarkupPercent;
			CalculateTabularSectionRowSUM(DocumentForm, TabularSectionRow);
		EndDo;
	EndIf;
	
EndProcedure // RefillTabularSectionPricesByPriceKind()

// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
// 
Procedure RefillTabularSectionPricesByCounterpartyPriceKind(DocumentForm, TabularSectionName) Export
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				DocumentForm.Object.Date);
	DataStructure.Insert("Company",			DocumentForm.Counterparty);
	DataStructure.Insert("CounterpartyPriceKind",	DocumentForm.Object.CounterpartyPriceKind);
	DataStructure.Insert("DocumentCurrency",		DocumentForm.Object.DocumentCurrency);
	DataStructure.Insert("AmountIncludesVAT",	DocumentForm.Object.AmountIncludesVAT);
	
	For Each TSRow IN DocumentForm.Object[TabularSectionName] Do
		
		TSRow.Price = 0;
		
		If Not ValueIsFilled(TSRow.ProductsAndServices) Then
			Continue;	
		EndIf; 
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("ProductsAndServices",		TSRow.ProductsAndServices);
		TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
		TabularSectionRow.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		TabularSectionRow.Insert("VATRate",			TSRow.VATRate);
		TabularSectionRow.Insert("Price",				0);
		
		DocumentTabularSection.Add(TabularSectionRow);
		
	EndDo;
		
	SmallBusinessServer.GetPricesTabularSectionByCounterpartyPriceKind(DataStructure, DocumentTabularSection);
		
	For Each TSRow IN DocumentTabularSection Do

		SearchStructure = New Structure;
		SearchStructure.Insert("ProductsAndServices",		TSRow.ProductsAndServices);
		SearchStructure.Insert("Characteristic",		TSRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		SearchStructure.Insert("VATRate",			TSRow.VATRate);
		
		SearchResult = DocumentForm.Object[TabularSectionName].FindRows(SearchStructure);
		
		For Each ResultRow IN SearchResult Do
			
			ResultRow.Price = TSRow.Price;
			CalculateTabularSectionRowSUM(DocumentForm, ResultRow);
			
		EndDo;
		
	EndDo;
	
EndProcedure // RefillTabularSectionPricesByPriceKind()

// Recalculate price by document tabular section currency after changes in the "Prices and currency" form.
//
// Parameters:
//  PreviousCurrency - CatalogRef.Currencies,
//                 contains reference to the previous currency.
//
Procedure RecalculateTabularSectionPricesByCurrency(DocumentForm, PreviousCurrency, TabularSectionName) Export
	
	RatesStructure = SmallBusinessServer.GetCurrencyRates(PreviousCurrency, DocumentForm.Object.DocumentCurrency, DocumentForm.Object.Date);
																   
	For Each TabularSectionRow IN DocumentForm.Object[TabularSectionName] Do
		
		// Price.
		If TabularSectionRow.Property("Price") Then
			
			TabularSectionRow.Price = RecalculateFromCurrencyToCurrency(TabularSectionRow.Price, 
																	RatesStructure.InitRate, 
																	RatesStructure.ExchangeRate, 
																	RatesStructure.RepetitionBeg, 
																	RatesStructure.Multiplicity);
																	
			CalculateTabularSectionRowSUM(DocumentForm, TabularSectionRow);
			
		// Amount.	
		ElsIf TabularSectionRow.Property("Amount") Then
			
			TabularSectionRow.Amount = RecalculateFromCurrencyToCurrency(TabularSectionRow.Amount, 
																	RatesStructure.InitRate, 
																	RatesStructure.ExchangeRate, 
																	RatesStructure.RepetitionBeg, 
																	RatesStructure.Multiplicity);														
					
			If TabularSectionRow.Property("DiscountMarkupPercent") Then
				
				// Discounts.
				If TabularSectionRow.DiscountMarkupPercent = 100 Then
					TabularSectionRow.Amount = 0;
				ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
					TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
				EndIf;
								
			EndIf;														
			
			VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
	        TabularSectionRow.VATAmount = ?(DocumentForm.Object.AmountIncludesVAT, 
								  				TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
								  				TabularSectionRow.Amount * VATRate / 100);
					        		
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(DocumentForm.Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndIf;
        		        
	EndDo; 

EndProcedure // RecalculateTabularSectionPricesByCurrency()

#Region DiscountCards

// Recalculate document tabular section amount after reading discount card.
Procedure RefillDiscountsTablePartAfterDiscountCardRead(DocumentForm, TabularSectionName) Export
																	   
	Discount = SmallBusinessServer.GetDiscountPercentByDiscountMarkupKind(DocumentForm.Object.DiscountMarkupKind) + DocumentForm.Object.DiscountPercentByDiscountCard;
	
	For Each TabularSectionRow IN DocumentForm.Object[TabularSectionName] Do
		
		TabularSectionRow.DiscountMarkupPercent = Discount;
		
		CalculateTabularSectionRowSUM(DocumentForm, TabularSectionRow);
		        
	EndDo;
	
EndProcedure // RecalculateTabularSectionAmountByCheckBoxAmountIncludesVAT()

#EndRegion

//////////////////////////////////////////////////////////////////////////////// 
// PROCEDURES AND FUNCTIONS FOR WORK WITH CUSTOMER INVOICE NOTES

// Sets hyperlink label for Customer invoice note
//
Procedure SetTextAboutInvoice(DocumentForm, Received = False) Export

	InvoiceFound = SmallBusinessServer.GetSubordinateInvoice(DocumentForm.Object.Ref, Received);
	If ValueIsFilled(InvoiceFound) Then
		DocumentForm.InvoiceText = InvoicePresentation(InvoiceFound.Number, InvoiceFound.Date);	
	Else
	    DocumentForm.InvoiceText = "Enter invoice note";
	EndIf;

EndProcedure // FillInCustomerInvoiceNoteText()

// Generates hyperlink label on Customer invoice note
//
Function InvoicePresentation(Date, Number) Export

	InvoiceText = NStr("en='No. %Number% from %Date% y.';ru='№ %Номер% от %Дата% г.'");
	InvoiceText = StrReplace(InvoiceText, "%Number%", Number);
	InvoiceText = StrReplace(InvoiceText, "%Date%", Format(Date, "DF=dd.MM.yyyy"));	
	Return InvoiceText;

EndFunction // GetCustomerInvoiceNotePresentation()

// Sets hyperlink label for Customer invoice note
//
Procedure OpenInvoice(DocumentForm, Received = False) Export
	
	InvoiceFound = SmallBusinessServer.GetSubordinateInvoice(DocumentForm.Object.Ref, Received);
	
	If DocumentForm.Object.DeletionMark 
		AND Not ValueIsFilled(InvoiceFound) Then
		Message = New UserMessage();
		Message.Text = NStr("en='The invoice can not be entered on the base of the document marked for deletion!';ru='Счет-фактуру нельзя вводить на основании документа, помеченного на удаление!'");	
		Message.Message();
		Return;	
	EndIf;
	
	If DocumentForm.Modified Then
		Message = New UserMessage();
		Message.Text = NStr("en='Document was changed. First, you should write document.';ru='Документ был изменен. Сначала следует записать документ!'");	
		Message.Message();
		Return;	
	EndIf;
	
	If Not ValueIsFilled(DocumentForm.Object.Ref) Then
		Message = New UserMessage();
		Message.Text = NStr("en='Document is not written. First, you should write document.';ru='Документ не записан. Сначала следует записать документ!'");	
		Message.Message();
		Return;	
	EndIf;
	
	If Received Then
		FormName = "Document.SupplierInvoiceNote.ObjectForm";
	Else
		FormName = "Document.CustomerInvoiceNote.ObjectForm";
	EndIf;
	
	// Open and enter new document
	ParametersStructureAccountInvoice = New Structure;
	If ValueIsFilled(InvoiceFound) Then
		
		ParametersStructureAccountInvoice.Insert("Key", InvoiceFound.Ref);
		
	Else
		
		ParametersStructureAccountInvoice.Insert("Basis", DocumentForm.Object.Ref);
		
	EndIf;
	
	OpenForm(FormName, ParametersStructureAccountInvoice, DocumentForm);
	
EndProcedure // FillInCustomerInvoiceNoteText() 

// Procedure reports form opening to update label-hyperlink about customer invoice note
// 
// Used while printing UID (Universal
// transmission document) CustomerInvoiceNotesDescription. Array type (multidimensional).
// 
// Each array string contains description of created customer invoice note.
// Description decryption:
//  [0] - ref to
//  base document [1] - customer
//  invoice note date [2] - customer invoice note number
//
Procedure RefreshInscriptionsOnAccountsOpenInvoicesForms(InvoiceDetails)
	
	If TypeOf(InvoiceDetails) = Type("Array") Then
		
		For Each InvoiceCreated IN InvoiceDetails Do
		
			Structure = New Structure;
			Structure.Insert("BasisDocument", InvoiceCreated[0]);
			Structure.Insert("Presentation", SmallBusinessClient.InvoicePresentation(InvoiceCreated[2], InvoiceCreated[1]));
			Notify("RefreshOfTextAboutInvoice", Structure);
			
		EndDo;
		
	EndIf;
	
EndProcedure // UpdateLabelsAboutOpenFormsCustomerInvoiceNotes()

//////////////////////////////////////////////////////////////////////////////// 
// PROCEDURES AND FUNCTIONS OF ADDITIONAL ATTRIBUTES SUBSYSTEM

// Procedure expands values tree on form.
//
Procedure ExpandPropertiesValuesTree(FormItem, Tree) Export
	
	For Each Item IN Tree.GetItems() Do
		ID = Item.GetID();
		FormItem.Expand(ID, True);
	EndDo;
	
EndProcedure // ExpandPropertiesValuesTree()

// Procedure handler of the BeforeDeletion event.
//
Procedure PropertyValueTreeBeforeDelete(Item, Cancel, Modified) Export
	
	Cancel = True;
	Item.CurrentData.Value = Item.CurrentData.PropertyValueType.AdjustValue(Undefined);
	Modified = True;
	
EndProcedure // PropertyValuesTreeBeforeDeletion()

// Procedure handler of the OnStartEdit event.
//
Procedure PropertyValueTreeOnStartEdit(Item) Export
	
	Item.ChildItems.Value.TypeRestriction = Item.CurrentData.PropertyValueType;
	
EndProcedure // PropertyValueTreeOnStartEdit()

//////////////////////////////////////////////////////////////////////////////// 
// PROCEDURES AND FUNCTIONS OF WORK WITH DYNAMIC LISTS

// Deletes dynamic list filter item
//
//Parameters:
//List  - processed dynamic
//list, FieldName - layout field name filter by which should be deleted
//
Procedure DeleteListFilterItem(List, FieldName) Export
	
	CompositionField = New DataCompositionField(FieldName);
	Counter = 1;
	While Counter <= List.Filter.Items.Count() Do
		FilterItem = List.Filter.Items[Counter - 1];
		If TypeOf(FilterItem) = Type("DataCompositionFilterItem")
			AND FilterItem.LeftValue = CompositionField Then
			List.Filter.Items.Delete(FilterItem);
		Else
			Counter = Counter + 1;
		EndIf;	
	EndDo; 
	
EndProcedure // DeleteListFilterItem()

// Sets dynamic list filter item
//
//Parameters:
//List			- processed dynamic
//list, FieldName			- layout field name filter on which
//should be set, ComparisonKind		- filter comparison kind, by default - Equal,
//RightValue 	- filter value
//
Procedure SetListFilterItem(List, FieldName, RightValue, ComparisonType = Undefined) Export
	
	FilterItem = List.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue    = New DataCompositionField(FieldName);
	FilterItem.ComparisonType     = ?(ComparisonType = Undefined, DataCompositionComparisonType.Equal, ComparisonType);
	FilterItem.Use    = True;
	FilterItem.RightValue   = RightValue;
	FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
EndProcedure // SetListFilterItem()

// Changes dynamic list filter item
//
//Parameters:
//List         - processed dynamic
//list, FieldName        - layout field name filter on which
//should be set, ComparisonKind   - filter comparison kind, by default - Equal,
//RightValue - filter
//value, Set     - shows that it is required to set filter
//
Procedure ChangeListFilterElement(List, FieldName, RightValue = Undefined, Set = False, ComparisonType = Undefined, FilterByPeriod = False) Export
	
	DeleteListFilterItem(List, FieldName);
	
	If Set Then
		If FilterByPeriod Then
			SetListFilterItem(List, FieldName, RightValue.StartDate, DataCompositionComparisonType.GreaterOrEqual);
			SetListFilterItem(List, FieldName, RightValue.EndDate, DataCompositionComparisonType.LessOrEqual);		
		Else
		    SetListFilterItem(List, FieldName, RightValue, ComparisonType);	
		EndIf;		
	EndIf;
	
EndProcedure // ChangeListFilterItem()

// Function reads values of dynamic list filter items
//
Function ReadValuesOfFilterDynamicList(List) Export
	
	FillingData = New Structure;
	
	If TypeOf(List) = Type("DynamicList") Then
		
		For Each FilterDynamicListItem IN List.SettingsComposer.Settings.Filter.Items Do
			
			FilterName = String(FilterDynamicListItem.LeftValue);
			FilterValue = FilterDynamicListItem.RightValue;
			
			If Find(FilterName, ".") > 0 OR Not FilterDynamicListItem.Use Then
				
				Continue;
				
			EndIf;
			
			FillingData.Insert(FilterName, FilterValue);
			
		EndDo;
		
	EndIf;
	
	Return FillingData;
	
EndFunction // ReadDynamicListFilterValues()

///////////////////////////////////////////////////////////////////////////////// 
// CALCULATIONS MANAGEMENT PROCEDURES AND FUNCTIONS

// Procedure opens a form of totals calculations self management
//
Procedure TotalsControl() Export
	
EndProcedure //TotalsManagement()

///////////////////////////////////////////////////////////////////////////////// 
// PRINTING MANAGEMENT PROCEDURES AND FUNCTIONS

// Function generates title for the general form "Printing".
// CommandParameter - printing command parameter.
//
Function GetTitleOfPrintedForms(CommandParameter) Export
	
	If TypeOf(CommandParameter) = Type("Array") 
		AND CommandParameter.Count() = 1 Then 
		
		Return New Structure("FormTitle", CommandParameter[0]);
		
	EndIf;

	Return Undefined;
	
EndFunction // GetPrintedFormTitle()

// Processor procedure the "LabelPrinting" or "PriceTagCommand" command from documents 
// - Goods movements
// - Supplier invoice
//
Function PrintLabelsAndPriceTagsFromDocuments(CommandParameter) Export
	
	If CommandParameter.Count() > 0 Then
		
		ObjectArrayPrint = CommandParameter.PrintObjects;
		IsPriceTags = Find(CommandParameter.ID, "TagsPrinting") > 0;
		AddressInStorage = SmallBusinessServer.PreparePriceTagsAndLabelsPrintingFromDocumentsDataStructure(ObjectArrayPrint, IsPriceTags);
		ParameterStructure = New Structure("AddressInStorage", AddressInStorage);
		OpenForm("DataProcessor.PrintLabelsAndTags.Form.Form", ParameterStructure, , New UUID);
		
	EndIf;
	
	Return Undefined;
	
EndFunction // LabelsFromGoodsMovementPrinting()

Function GenerateContractForms(CommandParameter) Export
	
	For Each PrintObject IN CommandParameter.PrintObjects Do
		
		Parameters = New Structure;
		Parameters.Insert("Key", SmallBusinessServer.GetContractDocument(PrintObject));
		Parameters.Insert("Document", PrintObject);
		ContractForm = GetForm("Catalog.CounterpartyContracts.ObjectForm", Parameters);
		OpenForm(ContractForm);
		ContractForm.Items.GroupPages.CurrentPage = ContractForm.Items.GroupPrintContract;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

Function PrintCounterpartyContract(CommandParameter) Export
	
	If CommandParameter.Form.FormName = "Catalog.CounterpartyContracts.Form.ItemForm" Then 
		PrintingSource = CommandParameter.Form;
	Else
		FormParameters = New Structure("Key", CommandParameter.Form.Items.List.CurrentData.Ref);
		ContractForm = GetForm("Catalog.CounterpartyContracts.ObjectForm", FormParameters);
		OpenForm(ContractForm);
		PrintingSource = ContractForm;
	EndIf;
	
	PrintingSource.Items.GroupPages.CurrentPage = PrintingSource.Items.GroupPrintContract;
	
	If CommandParameter.Form.FormName = "Catalog.CounterpartyContracts.Form.ItemForm" Then
		
		Object = CommandParameter.Form.Object;
		Contract = PrintingSource.ContractHTMLDocument;
		
		If Not ValueIsFilled(Object.ContractForm) Then 
			Return Undefined;
		EndIf;
		
		FilterParameters = New Structure;
		FilterParameters.Insert("FormRefs", Object.ContractForm);
		
		EditedParametersArray = Object.EditableParameters.FindRows(FilterParameters);
		AllEditedParametersFilled = True;
		For Each String IN EditedParametersArray Do 
			If Find(Contract, String.ID) <> 0 Then
				If Not ValueIsFilled(String.Value) Then 
					AllEditedParametersFilled = False;
					Break;
				EndIf;
			EndIf;
		EndDo;
		
		If Not AllEditedParametersFilled Then
			ShowQueryBox(New NotifyDescription("PrintCounterpartyContractQuestion", ThisObject,
			               New Structure("PrintingSource", PrintingSource)),
			               NStr("en='Not all manually edited fields are filled in, continue printing?';ru='Не все редактируемые вручную поля заполнены, продолжить печать?'"), QuestionDialogMode.YesNo);
		Else
			PrintCounterpartyContractEnd(PrintingSource);
		EndIf;
	EndIf;
	
	Return Undefined;
	
EndFunction

Function PrintCounterpartyContractQuestion(Result, AdditionalParameters) Export
	
	PrintingSource = AdditionalParameters.PrintingSource;
	
	If Result = DialogReturnCode.Yes Then
		PrintCounterpartyContractEnd(PrintingSource);
	EndIf;
	
EndFunction

Function PrintCounterpartyContractEnd(PrintingSource)
	
	document = PrintingSource.Items.ContractHTMLDocument.Document;
	If document.execCommand("Print") = False Then 
		document.defaultView.print();
	EndIf;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////// 
// PREDEFINED PROCEDURES AND FUNCTIONS OF EMAIL SENDING

// Interface client procedure that supports call of new email editing form.
// While sending email via the standard common form MessageSending messages are not saved in the infobase.
//
// For the parameters, see description of the WorkWithPostalMailClient.CreateNewEmail function.
//
Procedure OpenEmailMessageSendForm(Sender, Recipient, Subject, Text, FileList, BasisDocuments, DeleteFilesAfterSend, OnCloseNotifyDescription) Export
	
	EmailParameters = New Structure;
	
	EmailParameters.Insert("FillingValues", New Structure("EventType", PredefinedValue("Enum.EventTypes.Email")));
	
	EmailParameters.Insert("UserAccount", Sender);
	EmailParameters.Insert("Whom", Recipient);
	EmailParameters.Insert("Subject", Subject);
	EmailParameters.Insert("Body", Text);
	EmailParameters.Insert("Attachments", FileList);
	EmailParameters.Insert("BasisDocuments", BasisDocuments);
	EmailParameters.Insert("DeleteFilesAfterSend", DeleteFilesAfterSend);
	
	OpenForm("Document.Event.Form.EmailForm", EmailParameters, , , , , OnCloseNotifyDescription);
	
EndProcedure

// Creates email by contact information.
// While email is generated with the standard procedure, the information about object contact is not passed to a sending form
//
// For the parameters, see description of the ContactInformationManagementClient.CreateEmail function.
//
Procedure CreateEmail(Val FieldsValues, Val Presentation = "", ExpectedKind = Undefined, FormObject) Export
	
	ContactInformation = ContactInformationManagementServiceServerCall.CastContactInformationXML(
		New Structure("FieldsValues, Presentation, ContactInformationKind", FieldsValues, Presentation, ExpectedKind));
		
	InformationType = ContactInformation.ContactInformationType;
	If InformationType <> PredefinedValue("Enum.ContactInformationTypes.EmailAddress") Then
		Raise StrReplace(NStr("en='You can not create email by contact information with the type ""%1""';ru='Нельзя создать письмо по контактной информацию с типом ""%1""'"),
			"%1", InformationType);
	EndIf;
	
	XMLData = ContactInformation.DataXML;
	MailAddress = ContactInformationManagementServiceServerCall.RowCompositionContactInformation(XMLData);
	If TypeOf(MailAddress) <> Type("String") Then
		Raise NStr("en='Error of the email address obtaining, incorrect type of the contact details';ru='Ошибка получения адреса электронной почты, неверный тип контактной информации'");
	EndIf;
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleWorkWithPostalMailClient = CommonUseClient.CommonModule("EmailOperationsClient");
		// SB. Begin
		ObjectContact = Undefined;
		FormObject.Property("Ref", ObjectContact);
		StructureRecipient = New Structure("Presentation, Address", ObjectContact, MailAddress);
		MailAddress = New Array;
		MailAddress.Add(StructureRecipient);
		// SB. End
		
		SendingParameters = New Structure("Recipient", MailAddress);
		ModuleWorkWithPostalMailClient.CreateNewEmail(SendingParameters);
		Return; 
	EndIf;
	
	// No mail subsystem, start the system one
	Notification = New NotifyDescription("CreateEmailByContactInformationEnd", ThisObject, MailAddress);
	SuggestionText = NStr("en='To send email, you should install extension for work with files.';ru='Для отправки письма необходимо установить расширение для работы с файлами.'");
	CommonUseClient.CheckFileOperationsExtensionConnected(Notification, SuggestionText);
	
EndProcedure


//////////////////////////////////////////////////////////////////////////////// 
// General module CommonUse does not support "Server call" any more.
// Corrections and support of a new behavior
//

// Replaces
// call CommonUse.ObjectAttributeValue from the CertificateSettingsTest() procedure of the EDCertificates catalog form
//
Function ReadAttributeValue_UserPassword_RememberCertificatePassword_Imprint_Ref(ObjectOrRef) Export
	
	Return SmallBusinessServer.ReadAttributeValue_UserPassword_RememberCertificatePassword_Imprint_Ref(ObjectOrRef);
	
EndFunction // ReadAttributeValue_CatalogCertificatesEPItemForm()

// Replaces
// call CommonUse.ObjectAttributeValue from the CommandProcessor() procedure of the  AgreementSettingsTest command of the EDUsageAgreements catalog
//
Function ReadAttributeValue_CatalogEDUsageAgreements_CommandAgreementSettingsTest(ObjectOrRef) Export
	
	Return SmallBusinessServer.ReadAttributeValue_CatalogEDUsageAgreements_CommandAgreementSettingsTest(ObjectOrRef);
	
EndFunction // ReadAttributeValue_CatalogCertificatesEPItemForm()

// Replaces
// call CommonUse.ObjectAttributeValue from the Add() procedure of the Price-list processor form
//
Function ReadAttributeValue_Owner(ObjectOrRef) Export
	
	Return SmallBusinessServer.ReadAttributeValue_Owner(ObjectOrRef);
	
EndFunction // ReadAttributeValue_ProcessorPriceListProcessorForm()

// Replaces
// call CommonUse.ObjectAttributeValue from the TreeSubordinateEDSelection() procedure of the EDTree form of the ElectronicDocuments processor
//
Function ReadAttributeValue_Agreement(ObjectOrRef) Export
	
	Return SmallBusinessServer.ReadAttributeValue_Agreement(ObjectOrRef);
	
EndFunction // ReadAttributeValue_Agreement()

// Replaces
// call CommonUse.ObjectAttributeValue from the CertificatePassword() procedure of the ItemFormViaOEDF form of the EDUsageAgreements catalog
//
Function ReadAttributeValue_SubscriberCertificate(ObjectOrRef) Export
	
	Return SmallBusinessServer.ReadAttributeValue_SubscriberCertificate(ObjectOrRef);
	
EndFunction // ReadAttributeValue_Agreement()

// Replaces
// call CommonUse.ObjectAttributeValue from the CertificatePassword() procedure of the ItemFormViaOEDF form of the EDUsageAgreements catalog
//
Function ReadAttributeValue_RememberCertificatePassword(ObjectOrRef) Export
	
	Return SmallBusinessServer.ReadAttributeValue_RememberCertificatePassword(ObjectOrRef);
	
EndFunction // ReadAttributeValue_Agreement()

// Replaces
// call CommonUse.ObjectAttributeValue from the CertificatePassword() procedure of the ItemFormViaOEDF form of the EDUsageAgreements catalog
//
Function ReadAttributeValue_UserPassword(ObjectOrRef) Export
	
	Return SmallBusinessServer.ReadAttributeValue_UserPassword(ObjectOrRef);
	
EndFunction // ReadAttributeValue_Agreement()

// Replaces
// call CommonUse.ObjectAttributeValue from the ProcessEDDecline()procedure of the EDViewForm form of the EDAttachedFiles catalog
//
Function ReadAttributeValue_EDExchangeMethod(ObjectOrRef) Export
	
	Return SmallBusinessServer.ReadAttributeValue_EDExchangeMethod(ObjectOrRef);
	
EndFunction // ReadAttributeValue_Agreement()

///////////////////////////////////////////////////////////////////////////////// 
// EXCHANGE WITH BANKS FUNCTIONS

// Initial work procedure with data import from statement
// 
// Parameters:
// 	- ExportedDocuments - Array - imported documents list
// 
// Returns:
// 		Boolean - True - if import is executed and false, if
//			user canceled or an error occurred while importing
Procedure ImportDataFromStatementFile(
		FormID = Undefined,
		FileName = "",
		Company = Undefined,
		BankAccount = Undefined,
		CFItemIncoming = Undefined,
		CFItemOutgoing = Undefined,
		PostImported = False,
		FillDebtsAutomatically = False,
		Application = "",
		Encoding = "Windows",
		FormatVersion = "1.02") Export
		
	CFItemIncoming = ?(ValueIsFilled(CFItemIncoming), CFItemIncoming, PredefinedValue("Catalog.CashFlowItems.PaymentFromCustomers"));
	CFItemOutgoing = ?(ValueIsFilled(CFItemOutgoing), CFItemOutgoing, PredefinedValue("Catalog.CashFlowItems.PaymentToVendor"));
	
	ExportedDocuments = New Array;
	AddressInStorage = "";
	Result = False;
	PathToFile1 = "kl_to_1c.txt";
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("AddressInStorage", AddressInStorage);
	AdditionalParameters.Insert("PathToFile1", PathToFile1);
	AdditionalParameters.Insert("Company", Company);
	AdditionalParameters.Insert("BankAccount", BankAccount);
	AdditionalParameters.Insert("CFItemIncoming", CFItemIncoming);
	AdditionalParameters.Insert("CFItemOutgoing", CFItemOutgoing);
	AdditionalParameters.Insert("PostImported", PostImported);
	AdditionalParameters.Insert("FillDebtsAutomatically", FillDebtsAutomatically);
	AdditionalParameters.Insert("Application", Application);
	AdditionalParameters.Insert("Encoding", Encoding);
	AdditionalParameters.Insert("FormatVersion", FormatVersion);
	AdditionalParameters.Insert("_FileName", FileName);
	AdditionalParameters.Insert("FormID", FormID);
	
	NotifyDescription = New NotifyDescription("EnableFileOperationsExtensionEnd", ThisObject, AdditionalParameters);
	BeginAttachingFileSystemExtension(NOTifyDescription);
	
EndProcedure

Procedure EnableFileOperationsExtensionEnd(Attached, AdditionalParameters) Export
	
	FormID = AdditionalParameters.FormID;
	
	#If Not WebClient Then
	If Attached Then
		
		If ValueIsFilled(AdditionalParameters._FileName) Then // If there are settings, then read file immediately.
			AdditionalParameters.PathToFile1 = AdditionalParameters._FileName;
			ReadTextDocument(AdditionalParameters);
		Else // If there are no settings, then file opening dialog.
			Dialog = New FileDialog(FileDialogMode.Open);
			Dialog.Title = NStr("en='Select file for import...';ru='Выберите файл для загрузки...'");
			Dialog.Filter = NStr("en='Files of exchange with 1C (*.txt)|*.txt|All files (*.*)|*.*';ru='Файлы обмена с 1С (*.txt)|*.txt|Все файлы (*.*)|*.*'");
			Dialog.FullFileName = AdditionalParameters.PathToFile1;
			Notification = New NotifyDescription("FileOpeningDialogEnd", ThisObject, AdditionalParameters);
			Dialog.Show(Notification);
		EndIf;
		
	Else
	#EndIf
		
		NotifyDescription = New NotifyDescription("ImportDataFromFileStatementsEnd", ThisObject, AdditionalParameters);
		BeginPutFile(NOTifyDescription, AdditionalParameters.AddressInStorage, AdditionalParameters.PathToFile1, True, AdditionalParameters.FormID);
		Return
		
	#If Not WebClient Then
	EndIf;
	#EndIf
	
EndProcedure

Procedure FileOpeningDialogEnd(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined OR SelectedFiles.Count() = 0  Then
		Return;
	EndIf;
	
	AdditionalParameters._FileName = SelectedFiles[0];
	AdditionalParameters.PathToFile1 = SelectedFiles[0];
	
	ReadTextDocument(AdditionalParameters);
	
EndProcedure

Procedure ReadTextDocument(AdditionalParameters)
	
	File = New TextDocument();
	
	If AdditionalParameters.Encoding = "DOS" Then
		Codin = TextEncoding.OEM;
	Else
		Codin = TextEncoding.ANSI;
	EndIf;
	
	Try
		File.Read(AdditionalParameters.PathToFile1, Codin);
	Except
		MessageText = NStr("en='An error occurred while reading file %File%.';ru='Ошибка чтения файла %Файл%.'");
		MessageText = StrReplace(MessageText, "%File%", AdditionalParameters.PathToFile1);
		ShowMessageBox(, MessageText);
		Return;
	EndTry;
	
	FileText = File.GetText();
	
	// User canceled sending file
	If StrLen(FileText) = 0 Then
		Return;
	EndIf;
	
	AddressInStorage = PutToTempStorage(FileText, AdditionalParameters.FormID);
	
	AdditionalParameters.AddressInStorage = AddressInStorage;
	ImportDataFromFileStatementsFragment(AdditionalParameters);
	
EndProcedure

Procedure ImportDataFromFileStatementsEnd(Successfully, Address, SelectedFileName, AdditionalParameters) Export
	
	If Successfully Then
		AdditionalParameters.AddressInStorage = Address;
		AdditionalParameters.PathToFile1 = SelectedFileName;
		ImportDataFromFileStatementsFragment(AdditionalParameters);
	EndIf;
	
EndProcedure

Procedure ImportDataFromFileStatementsFragment(AdditionalParameters)
	
	Status(
		NStr("en='The statement file is being loaded';ru='Загружается файл выписки'"),
		,
		NStr("en='Statement file is being imported';ru='Производится загрузка файла выписки'"),
		PictureLib.DataImport32
	);
	
	OpenForm(
		"DataProcessor.ClientBank.Form.FormImport",
		//( elmi #17 (112-00003) 
		//New Structure("FileForProcessorAddress, PathToFile, Company, CompanyBankAcc, CFItemIncoming, CFItemOutgoing, PostImported, FillDebtsAutomatically, Application, Encoding, FormatVersion",
		New Structure("AddressOfFileForProcessing, PathToFile, Company, BankAccountOfTheCompany, CFItemIncoming, CFItemOutgoing, PostImported, FillDebtsAutomatically, Application, Encoding, FormatVersion",
		//) elmi
		AdditionalParameters.AddressInStorage, AdditionalParameters.PathToFile1, AdditionalParameters.Company, AdditionalParameters.BankAccount, AdditionalParameters.CFItemIncoming, AdditionalParameters.CFItemOutgoing, AdditionalParameters.PostImported, AdditionalParameters.FillDebtsAutomatically, AdditionalParameters.Application, AdditionalParameters.Encoding, AdditionalParameters.FormatVersion)
	);
	
	
EndProcedure

//( elmi # 08.5
Procedure RenameTitleExchangeRateMultiplicity(Form, NameOfTable="") Экспорт
	
	If SmallBusinessServer.IndirectQuotationInUse() Then
		ElementExchangeRate = Form.Items.Find(NameOfTable + "ExchangeRate");	 
		If ElementExchangeRate <> Undefined Then
			 ElementExchangeRate.Title   = Nstr("lv='Кurss (koeficients)';en='Rate (multiplier)'");
			 ElementExchangeRate.ToolTip = Nstr("lv='Valsts valūtas vienību daudzums ārvalstu valūtas vienībā';en='Quantity of national currency units in foreign currency'");
		EndIf;
		ElementMultiplicity = Form.Items.Find(NameOfTable + "Multiplicity");
		If ElementMultiplicity <> Undefined Then
			ElementMultiplicity.Title   = Nstr("lv='Kurss (dalītājs)';en='Rate (divisor)'");
			ElementMultiplicity.ToolTip = Nstr("lv='Ārvalstu valūtas vienību daudzums valsts valūtas vienībā';en='Quantity of foreign currency units in national currency'");
		EndIf;
	EndIf;
	
EndProcedure
//) elmi


