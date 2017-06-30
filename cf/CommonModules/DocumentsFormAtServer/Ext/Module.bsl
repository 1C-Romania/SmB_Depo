&AtServer
Function GetExceptOperationTypes()
	ExceptOperationTypes = New Array;
	// Jack 27.06.2017
	//ExceptOperationTypes.Add(Enums.OperationTypesSalesOrder.ListOfSalesQuotasCloseByPositions);
	//ExceptOperationTypes.Add(Enums.OperationTypesSalesOrder.SalesQuotaCloseByPositions);
	//ExceptOperationTypes.Add(Enums.OperationTypesSalesOrder.SalesQuotaCloseFull);
	//ExceptOperationTypes.Add(Enums.OperationTypesSalesOrder.Comission);
	//
	//ExceptOperationTypes.Add(Enums.OperationTypesPurchaseOrder.PurchaseQuotasListCloseByPositions);
	//ExceptOperationTypes.Add(Enums.OperationTypesPurchaseOrder.PurchaseQuotaCloseFull);
	//ExceptOperationTypes.Add(Enums.OperationTypesPurchaseOrder.PurchaseQuotaCloseByPositions);
	//ExceptOperationTypes.Add(Enums.OperationTypesSalesRetail.ListOfSalesRetailQuotasCloseByPositions);
	//ExceptOperationTypes.Add(Enums.OperationTypesSalesRetail.SalesRetailQuotaCloseByPositions);
	//ExceptOperationTypes.Add(Enums.OperationTypesSalesRetail.SalesRetailQuotaCloseFull);
	//ExceptOperationTypes.Add(Enums.OperationTypesPurchaseInvoice.PurchaseOrdersList);
	//ExceptOperationTypes.Add(Enums.OperationTypesPurchaseInvoice.PurchaseReceiptsAndOrdersList);
	//ExceptOperationTypes.Add(Enums.OperationTypesPurchaseInvoice.PurchaseReceiptsList);
	//ExceptOperationTypes.Add(Enums.OperationTypesPurchaseCreditNoteReturn.PurchaseInvoiceCostsOnly);
	//ExceptOperationTypes.Add(Enums.OperationTypesPurchaseCreditNoteReturn.PurchaseInvoiceFixedAssets);
	//ExceptOperationTypes.Add(Enums.OperationTypesSalesDelivery.ListOfSalesOrders);
	//
	//ExceptOperationTypes.Add(Enums.OperationTypesPurchaseReturnOrder.ListOfPurchaseInvoices);
	//ExceptOperationTypes.Add(Enums.OperationTypesPurchaseReturnOrder.ListOfPurchaseReceipts);
	//ExceptOperationTypes.Add(Enums.OperationTypesPurchaseReturnOrder.ListOfPurchaseReturnQuotasCloseByPositions);
	//ExceptOperationTypes.Add(Enums.OperationTypesPurchaseReturnOrder.PurchaseReturnQuotaCloseByPositions);
	//ExceptOperationTypes.Add(Enums.OperationTypesPurchaseReturnOrder.PurchaseReturnQuotaCloseFull);
	//
	//ExceptOperationTypes.Add(Enums.OperationTypesSalesReturnReceipt.ListOfSalesReturnOrders);
	
	Return ExceptOperationTypes;
	
EndFunction
// Jack 27.06.2017
//&AtServer
//Function GetArrayPrefix(MetadataObject, Date)
//	
//	Query = New Query;
//	Query.Text = "SELECT
//	|	DocumentsNumberingSettingsSliceLast.Prefix
//	|FROM
//	|	InformationRegister.DocumentsNumberingSettings.SliceLast(&Date, DocumentType = &DocumentType) AS DocumentsNumberingSettingsSliceLast";
//	
//	Query.SetParameter("Date", Date);
//	Query.SetParameter("DocumentType", Documents[MetadataObject.Name].EmptyRef());
//	
//	ResultList = Query.Execute().Unload().UnloadColumn("Prefix");

//	Return ResultList;
//	
//EndFunction

Function GetFormInformation(Form) Export
	FormInformation = New Structure();
	
	//Form is "LIST" or "OBJECT"
	FormInformation.Insert("Type");
	
	//Structure whith form attributes availability
	AttributesAvailability = New Structure;
	FormInformation.Insert("IsAttribute", AttributesAvailability);
	
	AttributesAvailability.Insert("CurrentStatus",False);
	AttributesAvailability.Insert("Settlements",False);
	AttributesAvailability.Insert("SettlementsChoiceList",False);
	AttributesAvailability.Insert("BankAccountCurrency",False);
	AttributesAvailability.Insert("CashDeskCurrency",False);
	AttributesAvailability.Insert("ShowNumberPreview",False);	
	AttributesAvailability.Insert("NumberPreview",False);	
	
	AttributesArray = Form.GetAttributes();
	
	For Each StandartAttribute In DocumentsFormAtServerCached.GetStandartsObjectAttributes() Do 
		IsAttributeAtForm = False;
		For Each AttributFormInfo In AttributesArray Do
			If AttributFormInfo.Name = StandartAttribute.Key Then
				IsAttributeAtForm = True;
				Break;
			EndIf;
		EndDo;
		AttributesAvailability.Insert(StandartAttribute.Key, IsAttributeAtForm);
	EndDo;

	For Each Attribute In AttributesArray Do
		If Upper(Attribute.Name) = "LIST" OR Upper(Attribute.Name) = "OBJECT" Then
			FormInformation.Type = Upper(Attribute.Name);
		ElsIf AttributesAvailability.Property(Attribute.Name) Then
			AttributesAvailability[Attribute.Name] = True;
		EndIf;
			
	EndDo;
	
	Return FormInformation;
EndFunction

Procedure FillNewDocument(Form, ObjectMetadata)
	If CommonAtServer.IsDocumentAttribute("PriceType", ObjectMetadata) Then
		If Not ValueIsFilled(Form.Object["PriceType"]) Then
			Form.Object["PriceType"] = DefaultValuesAtServer.GetDefaultPriceType();
		EndIf;
		If CommonAtServer.IsDocumentAttribute("AmountType", ObjectMetadata) AND Not ValueIsFilled(Form.Object["AmountType"]) Then 
			Form.Object["AmountType"] = Form.Object["PriceType"]["AmountType"];
		EndIf;
		If CommonAtServer.IsDocumentAttribute("Currency", ObjectMetadata) Then
			If Not ValueIsFilled(Form.Object["Currency"]) Then 
				Form.Object["Currency"] = Form.Object["PriceType"]["Currency"];
				
				ExchangeRateDate =  CommonAtServer.GetDocumentExchangeRateDate(Form.Object, True);
				
				ExchangeRateRecord = AccountingAtServer.GetExchangeRateRecord(Form.Object.Currency, ExchangeRateDate);
				If CommonAtServer.IsDocumentAttribute("ExchangeRateDate", ObjectMetadata) Then
					Form.Object.ExchangeRateDate = ExchangeRateDate;
				EndIf;
				If CommonAtServer.IsDocumentAttribute("ExchangeRate", ObjectMetadata) Then
					Form.Object.ExchangeRate = ExchangeRateRecord.ExchangeRate;
				EndIf;
				If CommonAtServer.IsDocumentAttribute("NBPTableNumber", ObjectMetadata) Then
					Form.Object.NBPTableNumber = ExchangeRateRecord.NBPTableNumber;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	If CommonAtServer.IsDocumentAttribute("IssuePlace", ObjectMetadata) Then
		Form.Object.IssuePlace = DefaultValuesAtServer.GetDefaultIssuePlace();
	EndIf;
	
	Form.NewRef = FormsAtServer.GetNewObjectRef(ObjectMetadata.FullName());
EndProcedure

Procedure ListOnCreateAtServer(Form, FormInformation)
	Form.Items.List.ChoiceMode = Form.Parameters.ChoiceMode;		
	If Form.Items.List.ChoiceMode Then
		Form.List.AutoSaveUserSettings = False;
		ListAttributesArray = Form.GetAttributes("List");
		For Each ListAttribute In ListAttributesArray Do
			ValueForFilter = Undefined;
			Form.Parameters.Property("Filter_" + ListAttribute.Name, ValueForFilter);
			If ValueIsFilled(ValueForFilter) Then
				DataCompositionAtClientAtServer.SetUserSettingFilter(Form.List.SettingsComposer.UserSettings, ListAttribute.Name, ValueForFilter, True,DataCompositionComparisonType.Equal);
			EndIf;
		EndDo;
	EndIf;
EndProcedure

Procedure ObjectOnCreateAtServer(Form, FormInformation)
	ObjectMetadata = Form.Object.Ref.Metadata();
	
	AddStandartObjectAttributes(Form, FormInformation);
	Form.ObjectMetadataName = ObjectMetadata.Name;
	
	// Jack 27.06.2017
	//Form.PrefixList.LoadValues(GetArrayPrefix(ObjectMetadata, ?(Form.Object.Date = '00010101000000', CurrentDate(), Form.Object.Date)));
	//If IsInRole("Role_SystemSettings") Then
	//	Form.PrefixList.Add("NumberSettings", NStr("pl='Ustawienia...'; en='Settings...'"));
	//EndIf;
	//If Not Form.Items.Find("ChoicePrefix") = Undefined Then
	//	 Form.Items.ChoicePrefix.Visible = Form.PrefixList.Count() > 1 Or IsInRole("Role_SystemSettings");
	//EndIf;
	
	If Not Form.Items.Find("OperationType") = Undefined Then
		ExceptOperationTypes = GetExceptOperationTypes();
		OperationTypeMetadata = Form.Object["OperationType"].Metadata();
		For Each OperationTypeValue In Enums[OperationTypeMetadata.Name] Do
			If Not ExceptOperationTypes.Find(OperationTypeValue) = Undefined Then
				Continue;
			EndIf;
			Form.Items["OperationType"].ChoiceList.Add(OperationTypeValue);
		EndDo;
		Form.Items["OperationType"].Visible = (Form.Items["OperationType"].ChoiceList.Count() > 1);
	EndIf;
	
	If FormInformation.IsAttribute.Settlements Then
		FillingSettlementsTable(Form);
		Form.SettlementsCount = Form.Settlements.Count();
		Form.SettlementsTotalAmount = Form.Settlements.Total("GrossAmount");
	EndIf;
	
	FillingData = Undefined;
	If Form.Object.Ref.IsEmpty() And Form.Parameters.Property("FillingData", FillingData) And ValueIsFilled(FillingData) Then
		Form.Fill(FillingData);
	EndIf;
	
	// Jack 27.06.2017
	//If FormInformation.IsAttribute.SettlementsChoiceList Then
	//	SetUserFilterSettlementsChoice(Form);
	//EndIf;
	//
	//If FormInformation.IsAttribute.CurrentStatus Then
	//	Form.CurrentStatus = InformationRegisters.DocumentStatus.GetLast(, New Structure("Document", Form.Object.Ref)).Status;
	//EndIf;
	
	Form.ChangeDocumentsHeaderAtServer(False);
	
	If Not Form.Items.Find("FormPostAndClose") = Undefined Then
		Form.Items.FormPostAndClose.Representation = ButtonRepresentation.PictureAndText;
	EndIf;
	If Not Form.Items.Find("FormPost") = Undefined Then
		Form.Items.FormPost.Representation = ButtonRepresentation.PictureAndText;
		Form.Items.FormPost.Visible = Form.Object.Posted;
	EndIf;
	
	If Not Form.Items.Find("FormWrite") = Undefined Then
		Form.Items.FormWrite.Representation = ButtonRepresentation.PictureAndText;
		Form.Items.FormWrite.Visible = Not Form.Object.Posted;
		Form.Items.FormWrite.Title = NStr("en = 'Save draft'; pl = 'Zapisz wersję roboczą'");
	EndIf;

	RestorePrintSettings = CommonSettingsStorage.Load("PrintSettings_" + StrReplace(Form.FormName, ".", "_"),,,InfoBaseUsers.CurrentUser().Name);
	
	If RestorePrintSettings = Undefined OR RestorePrintSettings.PrintOnPostAndClose = True Then
		If Not Form.Items.Find("FormPostAndClose") = Undefined AND NOT Form.Commands.Find("PostPrintClose") = Undefined Then
			Form.Items.FormPostAndClose.CommandName = "PostPrintClose";
		EndIf;
	EndIf;
	
	If FormInformation.IsAttribute.BankAccountCurrency And CommonAtServer.IsDocumentAttribute("BankAccount", ObjectMetadata) Then
		If Not Form.Object.BankAccount.IsEmpty() Then
			Form.BankAccountCurrency = Form.Object.BankAccount.Currency;
		EndIf;
		DocumentsFormAtServer.SetExchangeRateListChoice(Form.Items.ExchangeRate, Form.BankAccountCurrency);
	ElsIf FormInformation.IsAttribute.CashDeskCurrency And CommonAtServer.IsDocumentAttribute("CashDesk", ObjectMetadata) Then
		If Not Form.Object.CashDesk.IsEmpty() Then
			Form.CashDeskCurrency = Form.Object.CashDesk.Currency;
		EndIf;
		DocumentsFormAtServer.SetExchangeRateListChoice(Form.Items.ExchangeRate, Form.CashDeskCurrency);
	EndIf;
	
	AdditionalAttributesServer.PutAddititionalAttributesOnForm(Form);		
	
	If Form.Object.Ref.IsEmpty() Then
		FillNewDocument(Form, ObjectMetadata);
	EndIf;
	
	// Jack 29.06.2017
	//If Form.Items.Find("SetNewPrefix")<>Undefined Then
	//	If CommonAtServer.IsDocumentAttribute("Prefix", ObjectMetadata) Then
	//		PrefixList = DocumentsPostingAndNumberingAtServer.GetArrayPrefix(ObjectMetadata,Form.Object.Date);
	//		Form.Items.SetNewPrefix.Visible = Form.Object.Ref.IsEmpty() AND PrefixList.Count() > 1;
	//	Else
	//		Form.Items.SetNewPrefix.Visible = False;
	//	EndIf;
	//EndIf;
	//
	//If Form.Items.Find("Number")<>Undefined Then	
	//	If Not IsInRole(Metadata.Roles.Right_General_ModifyDocumentsNumber) Then			
	//		Form.Items.Number.ReadOnly = True;
	//		Form.Items.Number.ChoiceButton = False;			
	//	EndIf;		
	//EndIf;
	//
	//If Form.Items.Find("NumberPreview")<>Undefined Then	
	//	If Not IsInRole(Metadata.Roles.Right_General_ModifyDocumentsNumber) Then			
	//		Form.Items.NumberPreview.ChoiceButton = False;			
	//	EndIf;				
	//EndIf;
	//
	//If FormInformation.IsAttribute.ShowNumberPreview AND Form.Object.Ref.IsEmpty() Then
	//	Form.ShowNumberPreview = True;
	//Endif;	
	
	//DialogsAtServer.AddDocumentTabularPartCodeColumn(Form);	
EndProcedure

Procedure SetVisibleCompanyItem(Form, ItemName = "Company") Export 
	
	Form.Items[ItemName].Visible = True;
	
EndProcedure

#Region BaseFormsProcedures
Procedure OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	// Jack 27.06.2017
	//If CurrentRunMode() = ClientRunMode.OrdinaryApplication Then
	//	CommonAtServer.AdjustFormGroupsToOrdinaryApplication(Form);
	//EndIf;
	
	FormInformation = GetFormInformation(Form);
	SetCommandsInterface(Form, Cancel, StandardProcessing, FormInformation);
		
	If FormInformation.Type = "LIST" Then
		ListOnCreateAtServer(Form, FormInformation);
	ElsIf FormInformation.Type = "OBJECT" Then
		ObjectOnCreateAtServer(Form, FormInformation);
	EndIf;
EndProcedure

Procedure BeforeWriteAtServer(ThisForm, Cancel, CurrentObject, WriteParameters) Export
	FormsAtServer.BeforeWriteAtServer(ThisForm, Cancel, CurrentObject, WriteParameters);
EndProcedure

Procedure AfterWriteAtServer(Form, CurrentObject, WriteParameters) Export
	//It`s don`t set the title correctly while first time writing object
	SetFormDocumentTitle(Form);
	
EndProcedure

Function Post(Form) Export
	Cancel = False;
	DocumentObject = FormDataToValue(Form.Object, Type("DocumentObject." + Form.ObjectMetadataName));
	
	If Not DocumentObject.CheckFilling() Then
		Return False;
	EndIf;
	
	WriteParameters = New Structure("PostingMode, WriteMode", ?(BegOfDay(DocumentObject.Date) = BegOfDay(CurrentDate()), DocumentPostingMode.RealTime, DocumentPostingMode.Regular), DocumentWriteMode.Posting);
	
	Try
		Form.BeforeWriteAtServer(Cancel, DocumentObject, WriteParameters);
	Except

	EndTry;
	
	If Cancel Then
		Return False;
	EndIf;
	
	Try
		DocumentObject.Write(DocumentWriteMode.Posting, ?(Form.Object.Ref.IsEmpty() AND BegOfDay(CurrentDate()) = BegOfDay(Form.Object.Date), DocumentPostingMode.RealTime, DocumentPostingMode.Regular));
	Except
		Return False;
	EndTry;
	ValueToFormData(DocumentObject, Form.Object);
	Form.Modified = False;
	Return True;
EndFunction

// Jack 27.06.2017
//Procedure NotificationProcessingAtServer(Form, EventName, Parameter) Export
//	If EventName = "AddingAdditionalAttributes" and Form.UUID = Parameter Then
//		AdditionalAttributesServer.PutUpdateAddititionalAttributesOnForm(Form);
//	ElsIf EventName = "LoadData" AND Form.UUID = Parameter.LoadingDestinationUUID Then
//		SelectedValue = Parameter;
//		
//		Object = Form.FormAttributeToValue("Object");
//		NewRowsArray = DocumentsTabularPartsProcessingAtServer.FillTabularSectionOnLoadingFromSpreadsheetResult(Object, SelectedValue);
//		Form.ValueToFormAttribute(Object, "Object");
//		Form.Modified = True;

//		UpdateRowsAfterLoadingFromSpreadsheet(Form, NewRowsArray,SelectedValue);
//		
//		DeleteFromTempStorage(Parameter.TempStorageAddress);
//	ElsIf EventName = "ChangeFiles" Then
//		If CommonAtServer.IsDocumentAttribute("MainPicture", Form.Object.Ref.Metadata()) Then
//			Form.Object.MainPicture = Parameter.MainPicture;
//			Form.Modified = True;
//			Try
//				Form.GetMainPicture();
//			Except
//			EndTry;
//		EndIf;
//	ElsIf EventName = "ChangePrefixList" Then
//		Form.PrefixList.LoadValues(DocumentsPostingAndNumberingAtServer.GetArrayPrefix(Metadata.Documents[Form.ObjectMetadataName],Form.Object.Date));
//		Form.PrefixList.Add("NumberSettings", NStr("pl='Ustawienia...'; en='Settings...'"));
//		SetFormDocumentTitle(Form);
//	EndIf;
//EndProcedure

#EndRegion

#Region Other
Procedure UpdateRowsAfterLoadingFromSpreadsheet(Form, NewRowsArray, ChoiceValue) Export
	
	ObjectValue = Form.FormAttributeToValue("Object");
	DocumentMetadata = Metadata.Documents[Form.ObjectMetadataName];
	ObjectMetadataName = Form.ObjectMetadataName;
	
	IsVAT = Common.IsDocumentTabularPartAttribute("VATRate", DocumentMetadata, ChoiceValue.TabularSectionName);
	IsPrice = Common.IsDocumentTabularPartAttribute("Price", DocumentMetadata, ChoiceValue.TabularSectionName);
	IsUnitOfMeasure = Common.IsDocumentTabularPartAttribute("UnitOfMeasure", DocumentMetadata, ChoiceValue.TabularSectionName);
	IsCurrency = Common.IsDocumentTabularPartAttribute("Currency", DocumentMetadata, ChoiceValue.TabularSectionName);	

	For Each NewRowIndex In NewRowsArray Do
		
		// Jack 29.06.2017
		//NewRow = ObjectValue.ItemsLines.Get(NewRowIndex);
		NewRow =  ObjectValue[ChoiceValue.TabularSectionName].Get(NewRowIndex);
		
		ActionsArray = New Array;
					
		ActionsArray.Add(New Structure("Name, Parameters","SetSalesPrice",New Structure("Object", Form.Object)));
		If IsVAT Then
			// Jack 27.06.2017
			//If NOT IsInRole(Metadata.Roles.Right_Sales_ToEditVATRateInSalesDocuments) Then
				NewRow.VATRate = Catalogs.VATRates.EmptyRef();
			//EndIf;
			
			// Jack 27.06.2017
			//If NewRow.VATRate.IsEmpty() And Not NewRow.Item.IsEmpty() Then
			//	If CommonAtServer.IsDocumentAttribute("Customer", DocumentMetadata) Then
			//		ActionsArray.Add(New Structure("Name, Parameters","SetVATRate",New Structure("Company, PartnerAccountingGroup, ItemAccountingGroup",ObjectValue.Company, ObjectValue.Customer.AccountingGroup, NewRow.Item.AccountingGroup)));
			//	ElsIf CommonAtServer.IsDocumentAttribute("Supplier", DocumentMetadata) Then
			//		ActionsArray.Add(New Structure("Name, Parameters","SetVATRate",New Structure("Company, PartnerAccountingGroup, ItemAccountingGroup",ObjectValue.Company, ObjectValue.Supplier.AccountingGroup, NewRow.Item.AccountingGroup)));
			//	EndIf;
			//EndIf;
		EndIf;
		
		If IsUnitOfMeasure And NewRow.UnitOfMeasure.IsEmpty() Then
			ActionsArray.Add(New Structure("Name, Parameters","SetSalesUnitOfMeasure", New Structure));
		EndIf;
		
		If IsPrice Then
			If NewRow.Price = 0 Then 
				ActionsArray.Add(New Structure("Name, Parameters","SetSalesPrice",New Structure("Object", ObjectValue)));
			Else
				If Common.IsDocumentTabularPartAttribute("Discount", DocumentMetadata, ChoiceValue.TabularSectionName) AND Common.IsDocumentTabularPartAttribute("InitialPrice", DocumentMetadata, ChoiceValue.TabularSectionName) Then
					ActionsArray.Add(New Structure("Name, Parameters","CalculateDiscountByPriceAndInitialPrice", New Structure));
				EndIf;
			EndIf;
			ActionsArray.Add(New Structure("Name, Parameters","CalculateRowAmountByPriceAndQuantity",New Structure));
		EndIf;
		
		If IsVAT Then
			ActionsArray.Add(New Structure("Name, Parameters","CalculateRowVATByAmount",New Structure("AmountType",ObjectValue.AmountType)));
		EndIf;
		
		If Common.IsDocumentTabularPartAttribute("NetAmount", DocumentMetadata, ChoiceValue.TabularSectionName) Then
			ActionsArray.Add(New Structure("Name, Parameters","CalculateRowNetAmountByAmount",New Structure("AmountType",ObjectValue.AmountType)));
		EndIf;
		If Common.IsDocumentTabularPartAttribute("GrossAmount", DocumentMetadata, ChoiceValue.TabularSectionName) Then
			ActionsArray.Add(New Structure("Name, Parameters","CalculateRowGrossAmountByAmount",New Structure("AmountType",ObjectValue.AmountType)));
		EndIf;
		
		If ObjectMetadataName = "OpeningBalanceDebtsWithEmployees" Then
			ActionsArray.Add(New Structure("Name, Parameters","SetRowValuesForOpeningBalanceDebtsWithEmployees", New Structure));							
		ElsIf ObjectMetadataName = "OpeningBalanceDebtsWithPartners" Then	
			ActionsArray.Add(New Structure("Name, Parameters","SetRowValuesForOpeningBalanceDebtsWithPartners", New Structure));									
		Else	
			If IsCurrency Then
				If Common.IsDocumentTabularPartAttribute("BankAccount", DocumentMetadata, ChoiceValue.TabularSectionName) Then
					ActionsArray.Add(New Structure("Name, Parameters","SetRowCurrency", New Structure("CurrencySourceColumn,Date","BankAccount",ObjectValue.Date)));				
				ElsIf Common.IsDocumentTabularPartAttribute("CashDesk", DocumentMetadata, ChoiceValue.TabularSectionName) Then					
					ActionsArray.Add(New Structure("Name, Parameters","SetRowCurrency", New Structure("CurrencySourceColumn,Date","CashDesk",ObjectValue.Date)));
				EndIf;
			EndIf;		
		EndIf; 
		
		If Common.IsDocumentTabularPartAttribute("AmountNational", DocumentMetadata, ChoiceValue.TabularSectionName) Then
			ActionsArray.Add(New Structure("Name, Parameters", "CalculateRowAmountNationalByAmount",New Structure));
		EndIf;
		
		If ObjectMetadataName = "EmployeesOffsettingOfDebts"
			AND ValueIsFilled(Form.CurrentEmployee) Then
			ActionsArray.Add(New Structure("Name, Parameters", "FillCurrentEmployee", New Structure("CurrentEmployee", Form.CurrentEmployee)));
		EndIf;
		
		DocumentsTabularPartsProcessingAtClientAtServer.ProceedTabularPartRow(NewRow, ActionsArray, Form);
		
	EndDo;
	GroupingColumns = New Array;
	GroupingColumns.Add("Item");
	GroupingColumns.Add("Price");
	GroupingColumns.Add("InitialPrice");
	GroupingColumns.Add("PricePromotion");
	GroupingColumns.Add("Discount");
	GroupingColumns.Add("UnitOfMeasure");
	GroupingColumns.Add("VATRate");
	GroupingColumns.Add("Employee");
	GroupingColumns.Add("Partner");
	GroupingColumns.Add("BankAccount");
	GroupingColumns.Add("CashDesk");
	GroupingColumns.Add("Currency");
	GroupingColumns.Add("ExchangeRate");
	GroupingColumns.Add("Document");
	GroupingColumns.Add("ReservationDocument");
	GroupingColumns.Add("SettlementType");
	GroupingColumns.Add("PaymentMethod");
	GroupingColumns.Add("Warehouse");
	GroupingColumns.Add("PrepaymentSettlement");
	GroupingColumns.Add("DocumentSettlementCurrency");
	GroupingColumns.Add("Description");
	GroupingColumns.Add("Account");
	GroupingColumns.Add("ExtDimension1");
	GroupingColumns.Add("ExtDimension2");
	GroupingColumns.Add("ExtDimension3");
	GroupingColumns.Add("Type");
	GroupingColumns.Add("Period");

	TotalingColumns = New Array;
	TotalingColumns.Add("Quantity");
	TotalingColumns.Add("Amount");
	TotalingColumns.Add("NetAmount");
	TotalingColumns.Add("AmountNational");
	TotalingColumns.Add("GrossAmount");
	TotalingColumns.Add("CurrencyAmount");
	TotalingColumns.Add("VAT");
	TotalingColumns.Add("Volume");
	TotalingColumns.Add("Weight");
	TotalingColumns.Add("DeclaredQuantity");
	TotalingColumns.Add("AmountDr");
	TotalingColumns.Add("AmountDrNational");
	TotalingColumns.Add("AmountDrSettlement");
	TotalingColumns.Add("AmountCr");
	TotalingColumns.Add("AmountCrNational");
	TotalingColumns.Add("AmountCrSettlement");
	
	GroupingColumnsString = "";
	For Each GroupingColumn In GroupingColumns Do
		If Common.IsDocumentTabularPartAttribute(GroupingColumn, DocumentMetadata, ChoiceValue.TabularSectionName) Then
			GroupingColumnsString = GroupingColumnsString + ?(GroupingColumnsString = "", "", ", ") + GroupingColumn;
		EndIf;
	EndDo;
	
	TotalingColumnsString = "";
	For Each TotalingColumn In TotalingColumns Do
		If Common.IsDocumentTabularPartAttribute(TotalingColumn, DocumentMetadata, ChoiceValue.TabularSectionName) Then
			TotalingColumnsString = TotalingColumnsString + ?(TotalingColumnsString = "", "", ", ") + TotalingColumn;
		EndIf;
	EndDo;
	
	// Jack 29.06.2017
	//ObjectValue.ItemsLines.GroupBy(GroupingColumnsString, TotalingColumnsString);
	ObjectValue[ChoiceValue.TabularSectionName].GroupBy(GroupingColumnsString, TotalingColumnsString);
	
	Form.ValueToFormAttribute(ObjectValue,"Object");
	Form.Modified = True;
	
EndProcedure

Procedure AddStandartObjectAttributes(Form, FormInformation)
	NewAttributes = New Array;
	For Each StandartAttribute In DocumentsFormAtServerCached.GetStandartsObjectAttributes() Do
		If Not FormInformation.IsAttribute[StandartAttribute.Key] Then 
			NewAttribute = New FormAttribute(StandartAttribute.Key, StandartAttribute.Value.Type, , "");
			NewAttributes.Add(NewAttribute);
		EndIf;
	EndDo;
	If NewAttributes.Count() > 0 Then
		Form.ChangeAttributes(NewAttributes);
	EndIf;
	
	Form.FormInformation = New FixedStructure(FormInformation);
	Form.ObjectTitle = CommonAtServer.GetObjectTitle(Form.Object.Ref);
	
	MetadataAttributes = New Structure;
	For Each Attribute In Form.Object.Ref.Metadata().Attributes Do 
		MetadataAttributes.Insert(Attribute.Name);
	EndDo;
	Form.HeaderAttributes = New FixedStructure(MetadataAttributes);
	
EndProcedure

Function GetTableDescription(TableName) Export
	TableNameStructure = New Structure;
	TableNameStructure.Insert("Payments", NStr("en='Payment';pl='Natychmiastowa zapłata'"));
	TableNameStructure.Insert("Prepayments", NStr("en='Prepayments';pl='Rozliczenie zapłaty'"));
	TableNameStructure.Insert("PrepaymentInvoiceVATLines", NStr("en='Included prepayment invoices';pl='Uwzględnienie faktury zaliczkowej'"));
	
	Return TableNameStructure[TableName];
EndFunction

Procedure FillingSettlementsTable(Form)
	MetadataDocument = Form.Object.Ref.Metadata();
	If Common.IsDocumentTabularPart("Payments", MetadataDocument) Then
		
		For Each DocumentRow In Form.Object.Payments Do
			
			NewRow = Form.Settlements.Add();
			
			NewRow.Type = "Payments";
			If Common.IsDocumentTabularPartAttribute("Document",MetadataDocument,"Payments") Then
				NewRow.Document = DocumentRow.Document;
			EndIf;
			NewRow.PaymentMethod = DocumentRow.PaymentMethod;
			If Common.IsDocumentTabularPartAttribute("CashDesk",MetadataDocument,"Payments") Then
				NewRow.BankCash = DocumentRow.CashDesk;
			ElsIf Common.IsDocumentTabularPartAttribute("BankCash",MetadataDocument,"Payments") Then
				NewRow.BankCash = DocumentRow.BankCash;
			EndIf;

			NewRow.GrossAmount = DocumentRow.Amount;

		EndDo;
	EndIf;
	If Common.IsDocumentTabularPart("Prepayments", MetadataDocument) Then
		For Each DocumentRow In Form.Object.Prepayments Do
			
			NewRow = Form.Settlements.Add();
			
			NewRow.Type = "Prepayments";
			NewRow.Partner = DocumentRow.Partner;
			NewRow.Document = DocumentRow.Document;
			NewRow.ReservationDocument = DocumentRow.ReservationDocument;
			If ValueIsNotFilled(NewRow.ReservationDocument) Then
				NewRow.ReservationDocument = Undefined;
			EndIf;
			If Common.IsDocumentTabularPartAttribute("AmountDr", MetadataDocument, "Prepayments") Then
				NewRow.GrossAmount = DocumentRow.AmountDr;
			ElsIf Common.IsDocumentTabularPartAttribute("AmountCr", MetadataDocument, "Prepayments") Then
				NewRow.GrossAmount = DocumentRow.AmountCr;
			Else
				NewRow.GrossAmount = 0;
			EndIf;
			
		EndDo;
	EndIf;
	If Common.IsDocumentTabularPart("PrepaymentInvoiceVATLines", MetadataDocument) Then
		For Each DocumentRow In Form.Object.PrepaymentInvoiceVATLines Do
			
			NewRow = Form.Settlements.Add();
			
			NewRow.Type = "PrepaymentInvoiceVATLines";
			FillPropertyValues(NewRow, DocumentRow);
			If ValueIsNotFilled(NewRow.ReservationDocument) Then
				NewRow.ReservationDocument = Undefined;
			EndIf;
			If CommonAtServer.IsDocumentAttribute("Customer", Metadata.Documents[Form.ObjectMetadataName]) Then
				NewRow.Partner = Form.Object.Customer;
			ElsIf CommonAtServer.IsDocumentAttribute("Supplier", Metadata.Documents[Form.ObjectMetadataName]) Then
				NewRow.Partner = Form.Object.Supplier;
			EndIf;
			NewRow.Document = DocumentRow.PrepaymentInvoice;
		EndDo;
	EndIf;
EndProcedure

Procedure SetFormDocumentTitle(Form) Export
	Form.AutoTitle = False;	
	
	SetHeaderValue(Form);
	
	ItemNumberPreview = Form.Items.Find("NumberPreview");
	If False AND ItemNumberPreview<>Undefined AND Form.ShowNumberPreview Then				
		Number = Form.NumberPreview;
	Else		
		If Form.Object.Ref.IsEmpty() Or (Form.ShowNumberPreview And TrimAll(Form.Object.Number) = "") Then
			DocumentObject = FormDataToValue(Form.Object, Type("DocumentObject." + Form.ObjectMetadataName));
			If DocumentObject.Date = '00010101' Then
				DocumentObject.Date = CurrentDate();
			EndIf;
			// Jack 27.06.2017
			//If TrimAll(Form.Object.Number) = "" Then
			//	Number = TrimAll(DocumentsPostingAndNumbering.GetDocumentAutoNumberPresentation(DocumentObject));
			//Else
				Number = Form.Object.Number;
			//EndIf;
		Else
			Number = Form.HeaderValue.CurrentNumber;
		EndIf;
	EndIf;		
		
	NumberTitle = TrimAll(Number);
	DateTitle = Format(?(Form.Object.Date = '00010101', CurrentDate(), Form.Object.Date), "DLF=D");
	OperationTypeDescription = "";
	MetadataObject = Form.Object.Ref.Metadata();
	If CommonAtServer.IsDocumentAttribute("OperationType", MetadataObject) Then
		WithoutBaseOperation = Form.Object.OperationType.Metadata().EnumValues.Find("WithoutBase");
		If WithoutBaseOperation = Undefined Then
			OperationTypeDescription = String(Form.Object.OperationType);
		Else
			If Not Enums[Form.Object.OperationType.Metadata().Name][WithoutBaseOperation.Name] = Form.Object.OperationType Then
				OperationTypeDescription = String(Form.Object.OperationType);
			EndIf;
		EndIf;
	EndIf;
	
	// Jack 27.06.2017
	//If CommonAtServer.UseMuliCompaniesMode() Then
		CompanyTitle = String(Form.Object.Company);
	//Else
	//	CompanyTitle = "";
	//EndIf;
	
	If CommonAtServer.IsDocumentAttribute("IssuePlace", MetadataObject) Then
		If ValueIsFilled(Form.Object.IssuePlace) Then
			CompanyTitle = CompanyTitle + " (" + Form.Object.IssuePlace + ")";
		EndIf;
	EndIf;
	
	Form.Title = Form.ObjectTitle + " " + NumberTitle + NStr("pl=' z '; en=' from '") + DateTitle +
					?(CompanyTitle = "", "", "; " + CompanyTitle) +
					?(OperationTypeDescription = "", "", "; " + OperationTypeDescription);
	
	If Form.FormInformation.IsAttribute.NumberPreview Then	
		Form.NumberPreview = Number;
	EndIf;

EndProcedure

Procedure ChangeDocumentsHeader(Form) Export
	SetFormDocumentTitle(Form);
EndProcedure

Function SetControlMarkIncompleteAndEnable(Item, Value, Enabled) Export
	
	Item.Enabled = Enabled;
	Item.AutoMarkIncomplete = Item.Enabled;
	Item.MarkIncomplete = Item.AutoMarkIncomplete AND ValueIsNotFilled(Value);

EndFunction

Function GetExchangeRateListChoice(Currency) Export
	
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
	
	Return ExchangeRatesValueList;
	
EndFunction

Procedure SetExchangeRateListChoice(Item, Currency) Export
	ListChoice = GetExchangeRateListChoice(Currency);
	Item.ChoiceList.Clear();
	For Each ExchangeRateItem In ListChoice Do
		Item.ChoiceList.Add(ExchangeRateItem.Value, ExchangeRateItem.Presentation);
	EndDo;
EndProcedure

Procedure SetCommandsInterface(Form, Cancel, StandardProcessing, FormInformation) 
	If FormInformation.Type = "OBJECT" AND Not Form.Items.Find("Number") = Undefined Then
		If Not Form.Items.Find("FormCommonCommandEditDocumentsHeader") = Undefined Then
			Form.Items.FormCommonCommandEditDocumentsHeader.OnlyInAllActions = True;
		EndIf;
		If Form.Object.ManualChangeNumber Then
			Form.Items.Number.WarningOnEditRepresentation = WarningOnEditRepresentation.DontShow;
		EndIf;
	EndIf;
	If Not Form.Items.Find("FormCommonCommandShowBookkeepingOperationCommand") = Undefined Then
		Form.Items.FormCommonCommandShowBookkeepingOperationCommand.Visible = CommonAtServer.GetVisibilityBookkeepingOperationCommand(Form.FormName);
	EndIf;
	If Not Form.Items.Find("FormCommonCommandAddAdditionalAttribute") = Undefined Then
		Form.Items.FormCommonCommandAddAdditionalAttribute.OnlyInAllActions = True;
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

Procedure SetHeaderValue(Form)
	StructureHeaderValue = New Structure("Date");
	If Form.HeaderAttributes.Property("Company") Then
		StructureHeaderValue.Insert("Company", Form.Object.Company);
	EndIf;
	If Form.HeaderAttributes.Property("OperationType") Then
		StructureHeaderValue.Insert("OperationType", Form.Object.OperationType);
	EndIf;
	If Form.Object.ManualChangeNumber Then
		StructureHeaderValue.Insert("CurrentNumber", Form.Object.Number);
	Else
		CurrentPrefix = DocumentsPostingAndNumbering.GetDocumentNumberPrefix(Form.Object);
		StructureHeaderValue.Insert("CurrentPrefix", CurrentPrefix);
		If Left(Form.Object.Ref.Number, StrLen(CurrentPrefix)) <> CurrentPrefix Then
			Form.ShowNumberPreview = True;
			Form.Object.Number = "";
			StructureHeaderValue.Insert("CurrentNumber", "");
		Else
			If Form.Object.Ref.IsEmpty() Then
				StructureHeaderValue.Insert("CurrentNumber", Form.Object.Number);
			Else
				Form.ShowNumberPreview = False;
				Form.Object.Number = Form.Object.Ref.Number;
				StructureHeaderValue.Insert("CurrentNumber", Form.Object.Ref.Number);
			EndIf;
		EndIf;
	EndIf;
	
	// by Jack 22.04.2017
	// StructureHeaderValue.Insert("Prefix", Form.Object.Prefix);


	Form.HeaderValue = New FixedStructure(StructureHeaderValue);
EndProcedure
#EndRegion

#Region BookkeepingOperationsTemplates
Function GetParameterStructure(Val Object, RowID) Export
	
	CurParameter = Object.Parameters.FindByID(RowID);
	FormParameters = New Structure;
	FormParameters.Insert("Name", CurParameter.Name);
	FormParameters.Insert("Presentation", CurParameter.Presentation);
	FormParameters.Insert("Type", ?(TrimAll(CurParameter.TypeStringInternal) <> "", ValueFromStringInternal(CurParameter.TypeStringInternal), Undefined));
	FormParameters.Insert("Value", CurParameter.Value);
	FormParameters.Insert("NotRequest", CurParameter.NotRequest);
	FormParameters.Insert("LinkByOwner", CurParameter.LinkByOwner);
	FormParameters.Insert("LinkByType", CurParameter.LinkByType);
	FormParameters.Insert("ExtDimensionNumber", CurParameter.ExtDimensionNumber);
	FormParameters.Insert("LongDescription", CurParameter.LongDescription);
	FormParameters.Insert("Obligatory", CurParameter.Obligatory);
	FormParameters.Insert("ParameterKind", CurParameter.ParameterKind);
	FormParameters.Insert("ParameterFormula", CurParameter.ParameterFormula);
	FormParameters.Insert("FieldName", CurParameter.FieldName);
	FormParameters.Insert("TableName", CurParameter.TableName);
	FormParameters.Insert("TableKind", CurParameter.TableKind);
	FormParameters.Insert("LineNumber", CurParameter.LineNumber);	
	FormParameters.Insert("IsNew", False);		
	FormParameters.Insert("DocumentBase", Object.DocumentBase);	
	Return FormParameters
EndFunction 

Function GetTableKindAndName(Val ThisObject, ParametersStructure, TableBoxName, CurrentRowID, CurrentColumnName) Export
	CurrentRow = ThisObject[TableBoxName].FindByID(CurrentRowID);	
	ExtDimensionDescription = "";
	ColumnTypes = AccountingAtServer.GetAccountingRecordsColumnType(ThisObject.Ref, TableBoxName, CurrentRow, CurrentColumnName, ExtDimensionDescription);			
	ParametersStructure.Insert("TypeRestriction", ColumnTypes);

	TableKindFilter = New ValueList;
	TableKindFilter.Add(Enums.BookkeepingOperationTemplateTableKind.DocumentRecords);
	If Common.IsDocumentTabularPartAttribute("TableKind", ThisObject.Ref.Metadata(), TableBoxName)
		AND Common.IsDocumentTabularPartAttribute("TableName", ThisObject.Ref.Metadata(), TableBoxName) Then
		
		If TableKindFilter.FindByValue(CurrentRow.TableKind) = Undefined Then
			TableKindFilter.Add(CurrentRow.TableKind);
		EndIf;	
		ParametersStructure.Insert("TableKind", CurrentRow.TableKind);
		ParametersStructure.Insert("TableName", CurrentRow.TableName);			
	Else				
		ParametersStructure.Insert("TableKind", Enums.BookkeepingOperationTemplateTableKind.DocumentRecords);
		ParametersStructure.Insert("TableName", "");		
	EndIf;	
			
	If ThisObject.DocumentBase <> Undefined Then
		ParametersStructure.Insert("ParameterKind", Enums.BookkeepingOperationTemplateParameterKinds.LinkedToDocumentBase);
	EndIf;	
	
	ParametersStructure.Insert("TableKindFilter", TableKindFilter);
EndFunction

Function GetObjectFieldName(ThisForm, CurrentItemName) Export
	CurrentItemDataPath = ThisForm.Items[CurrentItemName].DataPath;
	Return Right(CurrentItemDataPath, StrLen(CurrentItemDataPath) - StrFind(CurrentItemDataPath, ".", SearchDirection.FromEnd)); 	
EndFunction  


Function GetParentRowsByKindFormItem(TableKind, AllRecords) Export
	If TableKind = PredefinedValue("Enum.BookkeepingOperationTemplateTableKind.TabularSection") Then
		
		TabularSectionRows = Undefined;
		For Each Row In AllRecords.GetItems() Do
			If Row.TableName = "AllTabularSections" Then
				TabularSectionRows = Row;
			EndIf;
		EndDo;		                                             
		
		If TabularSectionRows = Undefined Then			
			TabularSectionRows = AllRecords.GetItems().Add();
			TabularSectionRows.TableName = "AllTabularSections";
			TabularSectionRows.TableSynonym = Nstr("en = 'Tabular sections'; pl = 'Sekcje tabelaryczne'");
			TabularSectionRows.TableKind = Enums.BookkeepingOperationTemplateTableKind.EmptyRef();
			TabularSectionRows.TablePicture = PictureLib.TabularSectionGroup;
			TabularSectionRows.Filter = New ValueList();
			TabularSectionRows.Filter.Add(Enums.BookkeepingOperationTemplateTableKind.TabularSection);
			
		EndIf;	
		
		TablePicture = PictureLib.TabularSection;
		
		ParentRows = TabularSectionRows; 
		
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterNonperiodic
		OR TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterPeriodic Then
		InformationRegisterRows = Undefined;
		For Each Row In AllRecords.GetItems() Do
			If Row.TableName = "AllInformationRegisters" Then
				InformationRegisterRows = Row;
			EndIf;
		EndDo;				
		
		If InformationRegisterRows = Undefined Then
			
			InformationRegisterRows = AllRecords.GetItems().Add();
			InformationRegisterRows.TableName = "AllInformationRegisters";
			InformationRegisterRows.TableSynonym = Nstr("en = 'Information registers'; pl = 'Rejestry informacji'");
			InformationRegisterRows.TableKind = Enums.BookkeepingOperationTemplateTableKind.EmptyRef();
			InformationRegisterRows.TablePicture = PictureLib.InformationRegistersGroup;
			InformationRegisterRows.Filter = New ValueList();
			InformationRegisterRows.Filter.Add(Enums.BookkeepingOperationTemplateTableKind.InformationRegisterNonperiodic);
			InformationRegisterRows.Filter.Add(Enums.BookkeepingOperationTemplateTableKind.InformationRegisterPeriodic);
			
		EndIf;	
		
		TablePicture = PictureLib.InformationRegister;
		
		ParentRows = InformationRegisterRows; 
		
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.AccumulationRegister Then	
		AccumulationRegisterRows = Undefined;
		
		For Each Row In AllRecords.GetItems() Do
			If Row.TableName = "AllAccumulationRegisters" Then
				AccumulationRegisterRows = Row;
			EndIf;
		EndDo;				
		
		If AccumulationRegisterRows = Undefined Then
			
			AccumulationRegisterRows = AllRecords.GetItems().Add();
			AccumulationRegisterRows.TableName = "AllAccumulationRegisters";
			AccumulationRegisterRows.TableSynonym = Nstr("en = 'Accumulation registers'; pl = 'Rejestry akumulacji'");
			AccumulationRegisterRows.TableKind = Enums.BookkeepingOperationTemplateTableKind.EmptyRef();
			AccumulationRegisterRows.TablePicture = PictureLib.AccumulationRegistersGroup;
			AccumulationRegisterRows.Filter = New ValueList();
			AccumulationRegisterRows.Filter.Add(Enums.BookkeepingOperationTemplateTableKind.AccumulationRegister);
			
		EndIf;	
		
		TablePicture = PictureLib.AccumulationRegister;
		
		ParentRows = AccumulationRegisterRows; 
		
	Else
		
		ParentRows = AllRecords; 
		
	EndIf;
	
	Return ParentRows;
	
EndFunction	

Procedure SetUserFilterSettlementsChoice(Form)
	PartnerValue = Undefined;
	If CommonAtServer.IsDocumentAttribute("Customer", Form.Object.Ref.Metadata()) Then
		PartnerValue = Form.Object.Customer;
	ElsIf CommonAtServer.IsDocumentAttribute("Supplier", Form.Object.Ref.Metadata()) Then
		PartnerValue = Form.Object.Supplier;
	Else
		Return;
	EndIf;
	
	UserFilter = Form.SettlementsChoiceList.SettingsComposer.UserSettings.Items.Find(Form.SettlementsChoiceList.SettingsComposer.Settings.Filter.UserSettingID);
	ItemFilter = UserFilter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Partner");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.Use = True;
	ItemFilter.RightValue = PartnerValue;

	ItemFilter.UserSettingID = New UUID;
	
	Form.SettlementsChoiceList.Parameters.SetParameterValue("Partner", PartnerValue);

EndProcedure
#EndRegion
