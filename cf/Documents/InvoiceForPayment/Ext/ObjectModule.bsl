#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region DocumentFillingProcedures
	
Procedure FillingHandler(FillingData) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If Not CommonUse.ReferenceTypeValue(FillingData) Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(TabularSectionName(FillingData)) Then
		Return;
	EndIf;
	
	QueryResult = QueryDataForFilling(FillingData).Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	SelectionHeader = QueryResult.Select();
	SelectionHeader.Next();
	
	FillPropertyValues(ThisObject, SelectionHeader);
	
	If DocumentCurrency <> Constants.NationalCurrency.Get() Then
		CurrencyStructure = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = CurrencyStructure.ExchangeRate;
		Multiplicity = CurrencyStructure.Multiplicity;
	EndIf;
	
	ThisObject.Inventory.Clear();
	TabularSectionSelection = SelectionHeader[TabularSectionName(FillingData)].Select();
	While TabularSectionSelection.Next() Do
		FillPropertyValues(ThisObject.Inventory.Add(), TabularSectionSelection);
	EndDo;
	
	If TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") Then
		SelectionWorks = SelectionHeader.Works.Select();
		While SelectionWorks.Next() Do
			FillPropertyValues(ThisObject.Inventory.Add(), SelectionWorks);
		EndDo;
	EndIf;
	
	If GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
		SelectionDiscountsMarkups = SelectionHeader.DiscountsMarkups.Select();
		While SelectionDiscountsMarkups.Next() Do
			FillPropertyValues(ThisObject.DiscountsMarkups.Add(), SelectionDiscountsMarkups);
		EndDo;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total");
	
EndProcedure

Function QueryDataForFilling(FillingData)
	
	Wizard = New QuerySchema;
	Batch = Wizard.QueryBatch[0];
	Batch.SelectAllowed = True;
	Operator0 = Batch.Operators[0];
	Operator0.Sources.Add(FillingData.Metadata().FullName());
	For Each HeaderFieldDescription In HeaderFieldsDescription(FillingData) Do
		Operator0.SelectedFields.Add(HeaderFieldDescription.Key);
		If ValueIsFilled(HeaderFieldDescription.Value) Then
			Batch.Columns[Batch.Columns.Count() - 1].Alias = HeaderFieldDescription.Value;
		EndIf;
	EndDo;
	
	For Each CurFieldDescriptionTabularSectionInventory In FieldsDescriptionTabularSectionInventory(FillingData) Do
		Operator0.SelectedFields.Add(
		StringFunctionsClientServer.SubstituteParametersInString(
		"%1.%2",
		TabularSectionName(FillingData),
		CurFieldDescriptionTabularSectionInventory.Key));
		If ValueIsFilled(CurFieldDescriptionTabularSectionInventory.Value) Then
			Batch.Columns[Batch.Columns.Count() - 1].Alias = CurFieldDescriptionTabularSectionInventory.Value;
		EndIf;
	EndDo;
	
	For Each CurFieldDescriptionTabularSectionWorks In FieldsDescriptionTabularSectionWorks(FillingData) Do
		Operator0.SelectedFields.Add(CurFieldDescriptionTabularSectionWorks.Key);
		If ValueIsFilled(CurFieldDescriptionTabularSectionWorks.Value) Then
			ColumnNestedTable = Batch.Columns[Batch.Columns.Count() - 1];
			ColumnNestedTable.Columns[ColumnNestedTable.Columns.Count() - 1].Alias = CurFieldDescriptionTabularSectionWorks.Value;
		EndIf;
	EndDo;
	
	If GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
		Operator0.SelectedFields.Add("DiscountsMarkups.ConnectionKey");
		Operator0.SelectedFields.Add("DiscountsMarkups.DiscountMarkup");
		Operator0.SelectedFields.Add("DiscountsMarkups.Amount");
	EndIf;
	
	Operator0.Filter.Add("Ref = &Parameter");
	
	Result = New Query(Wizard.GetQueryText());
	Result.SetParameter("Parameter", FillingData);
	
	Return Result;
	
EndFunction

Function TabularSectionName(FillingData)
	
	TabularSectionNames = New Map;
	TabularSectionNames[Type("DocumentRef.CustomerOrder")] = "Inventory";
	TabularSectionNames[Type("DocumentRef.CustomerInvoice")] = "Inventory";
	TabularSectionNames[Type("DocumentRef.AcceptanceCertificate")] = "WorksAndServices";
	TabularSectionNames[Type("DocumentRef.ProcessingReport")] = "Products";
	
	Return TabularSectionNames[TypeOf(FillingData)];
	
EndFunction

Function HeaderFieldsDescription(FillingData)
	
	Result = New Map;
	
	FillingDataMetadata = FillingData.Metadata();
	
	Result.Insert("Ref", "BasisDocument");
	Result.Insert("Company");
	Result.Insert("Company.BankAccountByDefault", "BankAccount");
	
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "DiscountCard");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "DiscountPercentByDiscountCard");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "ExchangeRate");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "Multiplicity");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "AmountIncludesVAT");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "VATTaxation");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "Contract");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "Counterparty");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "DocumentCurrency");
	
	If GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
		Result.Insert("DiscountsAreCalculated");
	EndIf;
	
	Return Result;
	
EndFunction

Procedure AddAttributeIfItIsInDocument(ResultMap, FillingDataMetadata, AttributeName)
	
	If CommonUse.IsObjectAttribute(AttributeName, FillingDataMetadata) Then
		ResultMap.Insert(AttributeName);
	EndIf;
	
EndProcedure

Function FieldsDescriptionTabularSectionInventory(FillingData)
	
	Result = New Map;
	Result.Insert("ProductsAndServices");
	Result.Insert("Characteristic");
	Result.Insert("Content");
	Result.Insert("MeasurementUnit");
	Result.Insert("Quantity");
	Result.Insert("Price");
	Result.Insert("DiscountMarkupPercent");
	Result.Insert("Amount");
	Result.Insert("VATRate");
	Result.Insert("VATAmount");
	Result.Insert("Total");
	If TabularSectionName(FillingData) <> "WorksAndServices" Then
		Result.Insert("Batch");
	EndIf;
	
	If GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
		Result.Insert("ConnectionKey");
		Result.Insert("AutomaticDiscountAmount");
		Result.Insert("AutomaticDiscountsPercent");
	EndIf;
	
	Return Result;
	
EndFunction

Function FieldsDescriptionTabularSectionWorks(FillingData)
	
	Result = New Map;
	
	If TypeOf(FillingData) <> Type("DocumentRef.CustomerOrder") Then
		Return Result;
	EndIf;
	
	Result.Insert("Works.ProductsAndServices");
	Result.Insert("Works.Characteristic");
	Result.Insert("Works.Content");
	Result.Insert("Works.ProductsAndServices.MeasurementUnit", "MeasurementUnit");
	Result.Insert("Works.Quantity * Works.Factor * Works.Multiplicity", "Quantity");
	Result.Insert("Works.Price");
	Result.Insert("Works.AutomaticDiscountsPercent");
	Result.Insert("Works.Amount");
	Result.Insert("Works.VATRate");
	Result.Insert("Works.VATAmount");
	Result.Insert("Works.Total");
	
	If GetFunctionalOption("UseAutomaticDiscountsMarkups") Then
		Result.Insert("Works.ConnectionKeyForMarkupsDiscounts", "ConnectionKey");
		Result.Insert("Works.AutomaticDiscountAmount");
		Result.Insert("Works.AutomaticDiscountsPercent");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region EventHandlers

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.InvoiceForPayment.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total");
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
EndProcedure // BeforeWrite()

Procedure Filling(FillingData, StandardProcessing) Export
	
	ObjectFillingSB.FillDocument(ThisObject, FillingData, "FillingHandler");
	
EndProcedure // Filling()

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// 100% discount.
	AreManualDiscounts		= GetFunctionalOption("UseDiscountsMarkups");
	AreAutomaticDiscounts	= GetFunctionalOption("UseAutomaticDiscountsMarkups"); // AutomaticDiscounts
	If AreManualDiscounts OR AreAutomaticDiscounts Then
		For Each StringInventory IN Inventory Do
			// AutomaticDiscounts
			CurAmount = StringInventory.Price * StringInventory.Quantity;
			CurAmountManualDiscount		= ?(AreManualDiscounts, Round(CurAmount * StringInventory.DiscountMarkupPercent / 100, 2), 0);
			CurAmountAutomaticDiscount	= ?(AreAutomaticDiscounts, StringInventory.AutomaticDiscountAmount, 0);
			CurAmountDiscount			= CurAmountManualDiscount + CurAmountAutomaticDiscount;
			If StringInventory.DiscountMarkupPercent <> 100 AND CurAmountDiscount < CurAmount
				AND Not ValueIsFilled(StringInventory.Amount) Then
				MessageText = NStr("en='The ""Amount"" column is not populated in the %Number% line of the ""Inventory"" list.';ru='Не заполнена колонка ""Сумма"" в строке %Номер% списка ""Запасы"".'");
				MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Amount",
					Cancel
				);
			EndIf;
		EndDo;
	EndIf;
	
	If SchedulePayment
		AND CashAssetsType = Enums.CashAssetTypes.Noncash Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCash");
		
	ElsIf SchedulePayment
		AND CashAssetsType = Enums.CashAssetTypes.Cash Then
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccount");
		
	Else
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCash");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccount");
		
	EndIf;
	
	If SchedulePayment
		AND PaymentCalendar.Count() = 1
		AND Not ValueIsFilled(PaymentCalendar[0].PayDate) Then
		
		MessageText = NStr("en='The ""Payment date"" field is not filled in.';ru='Поле ""Дата оплаты"" не заполнено.'");
		SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText, , , "PayDate", Cancel);
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentCalendar.PaymentDate");
		
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
EndProcedure // FillCheckProcessing()

#EndRegion

#EndIf