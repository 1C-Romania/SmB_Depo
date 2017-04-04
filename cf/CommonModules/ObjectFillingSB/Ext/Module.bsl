
#Region Interface

Procedure FillDocument(DocumentObject, Val FillingData, Val FillingStrategy = Undefined, ExcludingProperties = "") Export
	
	If SkipFilling(FillingData) Then
		FillPropertyValues(DocumentObject, FillingData);
		Return;
	EndIf;
	
	CallHandlerBeforeFilling(FillingStrategy, DocumentObject, FillingData);
	
	ConvertFillingDataRefTypeToStructure(FillingData, DocumentObject);
	ConvertValuesFillingDataArrayTypeToRef(FillingData);
	SupplementRegistrationPeriod(FillingData, DocumentObject);
	SupplementValuesFromSettings(FillingData, DocumentObject);
	RenameEventFields(FillingData);
	SupplementCatalogPredefinedItems(FillingData, DocumentObject);
	RenameFields(FillingData, DocumentObject);
	SupplementAmountIncludesVAT(FillingData, DocumentObject);
	
	FillingData.Insert("Author", Users.CurrentUser());
	
	DeleteUnfilledExcludingProperties(FillingData, ExcludingProperties);
	FillPropertyValues(DocumentObject, FillingData,, ExcludingProperties);
	
	FillTabularSections(DocumentObject, FillingData);
	
EndProcedure

Procedure DeleteUnfilledExcludingProperties(FillingData, ExcludingProperties)
	
	If ExcludingProperties="" Then
		Return;
	EndIf;
	
	StructureExcludingProperties = CommonUseOverridable.StringToStructure(ExcludingProperties, ",");
	
	For Each PropertyName In StructureExcludingProperties Do
		If Not FillingData.Property(PropertyName.Key) Then
			StructureExcludingProperties.Delete(PropertyName.Key);
	    EndIf;
	EndDo;
	
	ExcludingProperties = CommonUseOverridable.StructureToString(StructureExcludingProperties, ",");
	
EndProcedure

Procedure SupplementCurrencies(ValuesFromSettings, DocumentObject) Export
	
	CurrencyByDefault = Constants.NationalCurrency.Get();
	
	For Each AttributeName In AttributeNames(CurrencyByDefault, DocumentObject) Do
		
		If ValuesFromSettings.Property(AttributeName) Then
			Continue;
		EndIf;
		
		If ValueIsFilled(DocumentObject[AttributeName]) Then
			Continue;
		EndIf;
		
		ValuesFromSettings.Insert(AttributeName, CurrencyByDefault);
		
	EndDo;
	
EndProcedure

Procedure RenameFields(FillingData, DocumentObject) Export
	
	RenamedFields = CommonUseClientServer.CopyStructure(FillingData);
	
	DeleteUnfilledValues(RenamedFields);
	
	RenameFieldsCompany(RenamedFields, DocumentObject);
	RenameFieldsCounterparty(RenamedFields);
	RenameFieldsContract(RenamedFields, DocumentObject);
	CheckCurrency(FillingData, RenamedFields);
	RenameFieldsDiscountCard(RenamedFields);
	RenameFieldsStructuralUnit(RenamedFields, DocumentObject);
	RenameFieldsPriceKind(RenamedFields);
	RenameFieldsCurrency(RenamedFields);
	
	CommonUseClientServer.ExpandStructure(FillingData, RenamedFields, True);
	
EndProcedure

Procedure CheckCurrency(FillingData, RenamedFields)
	
	If Not RenamedFields.Property("DocumentCurrency") Then
		Return;
	EndIf;
	
	If FillingData.Property("DocumentCurrency")
		And FillingData.DocumentCurrency = RenamedFields.DocumentCurrency Then
		Return;
	EndIf;
	
	FillingData.Delete("DocumentCurrency");
	
	If FillingData.Property("BankAccount") Then
		FillingData.Delete("BankAccount");
	EndIf;
	
	If RenamedFields.Property("BankAccount") Then
		RenamedFields.Delete("BankAccount");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions
	
Function SkipFilling(FillingData)
	
	If TypeOf(FillingData) <> Type("Structure") Then
		Return False;
	EndIf;
	
	If Not FillingData.Property("SkipFilling") Then
		Return False;
	EndIf;
	
	If TypeOf(FillingData.SkipFilling) = Type("Boolean") Then
		Return FillingData.SkipFilling;
	EndIf;
	
	Return False;
	
EndFunction

Procedure CallHandlerBeforeFilling(FillingStrategy, DocumentObject, FillingData)
	
	If Not ValueIsFilled(FillingStrategy) Then
		Return;
	EndIf;
	
	If TypeOf(FillingStrategy) = Type("String") Then
		WorkInSafeMode.ExecuteObjectMethod(
		DocumentObject,
		FillingStrategy,
		CommonUseClientServer.ValueInArray(FillingData));
		Return;
	EndIf;
	
	If TypeOf(FillingStrategy) <> Type("Map") Then
		Raise NStr("ru = 'Некорректный тип параметра ""ОбработчикЗаполнения"": ожидается Строка или Соответствие.'; en = 'Invalid parameter type ""FillingHandler"": expected String or Map.'");
	EndIf;
	
	NameHandlerBeforeFilling = FillingStrategy[TypeOf(FillingData)];
	
	If Not ValueIsFilled(NameHandlerBeforeFilling) Then
		Return;
	EndIf;
	
	WorkInSafeMode.ExecuteObjectMethod(
	DocumentObject,
	NameHandlerBeforeFilling,
	CommonUseClientServer.ValueInArray(FillingData));
	
КонецПроцедуры

Procedure ConvertFillingDataRefTypeToStructure(FillingData, DocumentObject)
	
	If Not ValueIsFilled(FillingData) Then
		FillingData = New Structure;
		Return;
	EndIf;
	
	If Not CommonUse.ReferenceTypeValue(FillingData) Then
		Return;
	EndIf;
	
	ParameterBasis	= FillingData;
	FillingData		= New Structure;
	
	For Each AttributeName In AttributeNames(ParameterBasis, DocumentObject) Do
		
		If ValueIsFilled(DocumentObject[AttributeName]) Then
			Continue;
		EndIf;
		
		FillingData.Insert(AttributeName, ParameterBasis);
		
	EndDo;
	
	SupplementFromBasisAmountIncludesVAT(FillingData, ParameterBasis);
	
EndProcedure

Procedure SupplementFromBasisAmountIncludesVAT(FillingData, ParameterBasis)
	
	If FillingData.Property("AmountIncludesVAT") Then
		Return;
	EndIf;
	
	MetadataObject = ParameterBasis.Metadata();
	
	If Not CommonUse.ThisIsDocument(MetadataObject) Then
		Return;
	EndIf;
	
	If Not CommonUse.IsObjectAttribute("AmountIncludesVAT", MetadataObject) Then
		Return;
	EndIf;
	
	FillingData.Insert(
	"AmountIncludesVAT",
	CommonUse.ObjectAttributeValue(
	ParameterBasis,
	"AmountIncludesVAT"));
	
EndProcedure

Procedure SupplementAmountIncludesVAT(FillingData, DocumentObject)
	
	If FillingData.Property("AmountIncludesVAT") Then
		Return;
	EndIf;
	
	If Not CommonUse.IsObjectAttribute("AmountIncludesVAT", DocumentObject.Metadata()) Then
		Return;
	EndIf;
	
	FillingData.Insert("AmountIncludesVAT", True);
	
EndProcedure

Procedure ConvertValuesFillingDataArrayTypeToRef(FillingData)
	
	For Each KeyAndValue In FillingData Do
		
		If TypeOf(KeyAndValue.Value) <> Type("Array") Then
			Continue;
		EndIf;
		
		If Not ValueIsFilled(KeyAndValue.Value) Then
			Continue;
		EndIf;
		
		LastArrayItem = KeyAndValue.Value[KeyAndValue.Value.UBound()];
		
		If TypeOf(LastArrayItem) = Type("Structure") Then
			Continue;
		EndIf;
		
		FillingData.Вставить(KeyAndValue.Key, LastArrayItem);
		
	EndDo;
	
EndProcedure

Procedure SupplementRegistrationPeriod(FillingData, DocumentObject)
	
	If FillingData.Property("RegistrationPeriod") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute("RegistrationPeriod", DocumentObject) Then
		Return;
	EndIf;
	
	FillingData.Insert("RegistrationPeriod", BegOfMonth(CurrentSessionDate()));
	
EndProcedure

Procedure SupplementValuesFromSettings(FillingData, DocumentObject)
	
	ValuesFromSettings = New Structure;
	
	SupplementCurrencies(ValuesFromSettings, DocumentObject);
	SupplementCompany(ValuesFromSettings, DocumentObject);
	SupplementDepartment(ValuesFromSettings, DocumentObject);
	SupplementStructuralUnit(ValuesFromSettings, DocumentObject, "MainCompany");
	SupplementStructuralUnit(ValuesFromSettings, DocumentObject, "MainWarehouse");
	SupplementMainResponsible(ValuesFromSettings, DocumentObject);
	SupplementPriceKind(ValuesFromSettings, DocumentObject);
	SupplementStampBase(ValuesFromSettings, DocumentObject);
	SupplementPositionResponsible(ValuesFromSettings, DocumentObject);
	SupplementReceiptDatePositionInPurchaseOrder(ValuesFromSettings, DocumentObject);
	SupplementJobOrderSettings(ValuesFromSettings, DocumentObject, FillingData);
	SupplementWorkKindPositionInWorkOrder(ValuesFromSettings, DocumentObject);
	SupplementShipmentDatePositionInCustomerOrder(ValuesFromSettings, DocumentObject);
	SupplementCustomerOrderPositionInShipmentDocuments(ValuesFromSettings, DocumentObject);
	SupplementPurchaseOrderPositionInReceiptDocuments(ValuesFromSettings, DocumentObject);
	SupplementCustomerOrderPositionInInventoryTransfer(ValuesFromSettings, DocumentObject);
	
	CommonUseClientServer.ExpandStructure(FillingData, ValuesFromSettings, False);
	
EndProcedure

#Region SupplementValuesFromSettings

Procedure SupplementCompany(ValuesFromSettings, DocumentObject)
	
	If NoUnfilledAttribute("Company", DocumentObject) Then
		Return;
	EndIf;
	
	CompanyByDefault = SmallBusinessReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"MainCompany");
	
	If ValueIsFilled(CompanyByDefault) Then
		ValuesFromSettings.Insert("Company", CompanyByDefault);
	EndIf;
	
EndProcedure
	
Procedure SupplementDepartment(ValuesFromSettings, DocumentObject)
	
	If NoUnfilledAttribute("Department", DocumentObject) Then
		Return;
	EndIf;
	
	DepartmentByDefault = SmallBusinessReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"MainDepartment");
	
	If ValueIsFilled(DepartmentByDefault) Then
		ValuesFromSettings.Insert("Department", DepartmentByDefault);
	EndIf;
	
EndProcedure

Procedure SupplementStructuralUnit(ValuesFromSettings, DocumentObject, SettingsName)
	
	If TypeOf(DocumentObject) = Type("DocumentObject.RetailReport") Then
		Return;
	EndIf;
	
	StructuralUnit = SmallBusinessReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	SettingsName);
	
	If Not ValueIsFilled(StructuralUnit) Then
		Return;
	EndIf;
	
	StructuralUnitType = CommonUse.ObjectAttributeValue(StructuralUnit, "StructuralUnitType");
	
	For Each Attribute In DocumentObject.Ref.Metadata().Attributes Do
		
		If ValuesFromSettings.Property(Attribute.Name) Then
			Continue;
		EndIf;
		
		If Not Attribute.Type.ContainsType(TypeOf(StructuralUnit)) Then
			Continue;
		EndIf;
		
		If Not StructuralUnitTypeToChoiceParameters(StructuralUnitType, Attribute.ChoiceParameters) Then
			Continue;
		EndIf;
		
		If ValueIsFilled(DocumentObject[Attribute.Name]) Then
			Continue;
		EndIf;
		
		ValuesFromSettings.Insert(Attribute.Name, StructuralUnit);
		
	EndDo;
	
EndProcedure

Procedure SupplementMainResponsible(ValuesFromSettings, DocumentObject)
	
	If NoUnfilledAttribute("Responsible", DocumentObject) Then
		Return;
	EndIf;
	
	MainResponsible = SmallBusinessReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"MainResponsible");
	
	If ValueIsFilled(MainResponsible) Then
		ValuesFromSettings.Insert("Responsible", MainResponsible);
	EndIf;
	
EndProcedure

Procedure SupplementPriceKind(ValuesFromSettings, DocumentObject)
	
	If ValuesFromSettings.Property("PriceKind")
		And ValueIsFilled(ValuesFromSettings.PriceKind) Then
		Return;
	EndIf;
	
	If TypeOf(DocumentObject.Ref) = Type("DocumentRef.RetailReport") Then
		Return;
	EndIf;
	
	If TypeOf(DocumentObject.Ref) = Type("DocumentRef.ReceiptCR") Then
		Return;
	EndIf;
	
	If TypeOf(DocumentObject.Ref) = Type("DocumentRef.ReceiptCRReturn") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute("PriceKind", DocumentObject) Then
		Return;
	EndIf;
	
	PriceKindByDefault = SmallBusinessReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"MainPriceKindSales");
	
	If ValueIsFilled(PriceKindByDefault) Then
		ValuesFromSettings.Insert("PriceKind", PriceKindByDefault);
	EndIf;
	
EndProcedure

Procedure SupplementStampBase(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject) <> Type("DocumentObject.CustomerInvoice")
		And TypeOf(DocumentObject) <> Type("DocumentObject.ProcessingReport") Then
		Return;
	EndIf;
	
	If ValueIsFilled(DocumentObject.StampBase) Then
		Return;
	EndIf;
	
	If ValueIsFilled(DocumentObject.Contract) Then
		ValuesFromSettings.Insert(
		"StampBase",
		StrTemplate(
		NStr("ru = 'Договор: %1'; en = 'Contract: %1'"),
		DocumentObject.Contract));
	EndIf;
	
EndProcedure

Procedure SupplementPositionResponsible(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentObject.RetailReport") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute("PositionResponsible", DocumentObject) Then
		Return;
	EndIf;
	
	PositionResponsible = SmallBusinessReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"PositionResponsible");
	
	If ValueIsFilled(PositionResponsible) Then
		ValuesFromSettings.Insert("PositionResponsible", PositionResponsible);
	EndIf;
	
EndProcedure

Procedure SupplementReceiptDatePositionInPurchaseOrder(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.PurchaseOrder") Then
		Return;
	EndIf;
	
	ReceiptDatePositionByDefault = SmallBusinessReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"ReceiptDatePositionInPurchaseOrder");
	
	If ValueIsFilled(ReceiptDatePositionByDefault) Then
		ValuesFromSettings.Insert("ReceiptDatePosition", ReceiptDatePositionByDefault);
	EndIf;
	
EndProcedure

Procedure SupplementJobOrderSettings(ValuesFromSettings, DocumentObject, FillingData)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.CustomerOrder") Then
		Return;
	EndIf;
	
	OperationKind = DocumentObject.OperationKind;
	
	If Not ValueIsFilled(OperationKind) Then
		FillingData.Property("OperationKind", OperationKind);
	EndIf;
	
	If OperationKind <> Enums.OperationKindsCustomerOrder.JobOrder Then
		Return;
	EndIf;
	
	JobOrderAttributes = New Map;
	JobOrderAttributes["WorkKindPosition"]		= Enums.AttributePositionOnForm.InHeader;
	JobOrderAttributes["UseProducts"]			= True;
	JobOrderAttributes["UseConsumerMaterials"]	= False;
	JobOrderAttributes["UseMaterials"]			= False;
	JobOrderAttributes["UsePerformerSalaries"]	= False;
	
	For Each KeyAndValue In JobOrderAttributes Do
		
		If Not CommonUse.IsObjectAttribute(
			KeyAndValue.Key,
			DocumentObject.Metadata()) Then
			Continue;
		EndIf;
		
		SettingsValue = SmallBusinessReUse.GetValueByDefaultUser(
		Users.CurrentUser(),
		StrTemplate(
		"%1InJobOrder",
		KeyAndValue.Key),
		KeyAndValue.Value);
		
		If ValueIsFilled(SettingsValue) Then
			ValuesFromSettings.Insert(KeyAndValue.Key, SettingsValue);
		Else
			ValuesFromSettings.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure SupplementWorkKindPositionInWorkOrder(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.WorkOrder") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute("WorkKindPosition", DocumentObject) Then
		Return;
	EndIf;
	
	WorkKindPositionByDefault = SmallBusinessReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"WorkKindPositionInWorkTask");
	
	If ValueIsFilled(WorkKindPositionByDefault) Then
		ValuesFromSettings.Insert("WorkKindPosition", WorkKindPositionByDefault);
	Else
		ValuesFromSettings.Insert("WorkKindPosition", Enums.AttributePositionOnForm.InHeader);
	EndIf;
	
EndProcedure

Procedure SupplementShipmentDatePositionInCustomerOrder(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.CustomerOrder") Then
		Return;
	EndIf;
	
	If DocumentObject.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute("ShipmentDatePosition", DocumentObject) Then
		Return;
	EndIf;
	
	ShipmentDatePositionByDefault = SmallBusinessReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"ShipmentDatePositionInCustomerOrder");
	
	If ValueIsFilled(ShipmentDatePositionByDefault) Then
		ValuesFromSettings.Insert("ShipmentDatePosition", ShipmentDatePositionByDefault);
	Else
		ValuesFromSettings.Insert("ShipmentDatePosition", Enums.AttributePositionOnForm.InHeader);
	EndIf;
	
EndProcedure

Procedure SupplementCustomerOrderPositionInShipmentDocuments(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.AcceptanceCertificate")
		And TypeOf(DocumentObject.Ref) <> Type("DocumentRef.CustomerInvoice") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute(
		"CustomerOrderPosition",
		DocumentObject) Then
		Return;
	EndIf;
	
	CustomerOrderPositionInShipmentDocuments = SmallBusinessReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"CustomerOrderPositionInShipmentDocuments");
	
	If ValueIsFilled(CustomerOrderPositionInShipmentDocuments) Then
		ValuesFromSettings.Insert("CustomerOrderPosition", CustomerOrderPositionInShipmentDocuments);
	Else
		ValuesFromSettings.Insert("CustomerOrderPosition", Enums.AttributePositionOnForm.InHeader);
	EndIf;
	
EndProcedure

Procedure SupplementPurchaseOrderPositionInReceiptDocuments(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.SupplierInvoice") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute(
		"PurchaseOrderPosition",
		DocumentObject) Then
		Return;
	EndIf;
	
	PurchaseOrderPositionInReceiptDocuments = SmallBusinessReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"PurchaseOrderPositionInReceiptDocuments");
	
	If ValueIsFilled(PurchaseOrderPositionInReceiptDocuments) Then
		ValuesFromSettings.Insert("PurchaseOrderPosition", PurchaseOrderPositionInReceiptDocuments);
	Else
		ValuesFromSettings.Insert("PurchaseOrderPosition", Enums.AttributePositionOnForm.InHeader);
	EndIf;
	
EndProcedure

Procedure SupplementCustomerOrderPositionInInventoryTransfer(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.InventoryTransfer") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute(
		"CustomerOrderPosition",
		DocumentObject) Then
		Return;
	EndIf;
	
	CustomerOrderPositionInInventoryTransfer = SmallBusinessReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"CustomerOrderPositionInInventoryTransfer");
	
	If ValueIsFilled(CustomerOrderPositionInInventoryTransfer) Then
		ValuesFromSettings.Insert("CustomerOrderPosition", CustomerOrderPositionInInventoryTransfer);
	Else
		ValuesFromSettings.Insert("CustomerOrderPosition", Enums.AttributePositionOnForm.InHeader);
	EndIf;
	
EndProcedure

#EndRegion

Procedure SupplementCatalogPredefinedItems(FillingData, DocumentObject)
	
	CatalogPredefinedItems = New Structure;
	
	SupplementPredefinedCompany(CatalogPredefinedItems, DocumentObject);
	SupplementPredefinedDepartment(CatalogPredefinedItems, DocumentObject);
	SupplementPredefinedStructuralUnits(CatalogPredefinedItems, DocumentObject);
	SupplementPredefinedPriceKind(CatalogPredefinedItems, DocumentObject);
	
	CommonUseClientServer.ExpandStructure(FillingData, CatalogPredefinedItems, False);
	
EndProcedure

#Region SupplementCatalogPredefinedItems

Procedure SupplementPredefinedCompany(CatalogPredefinedItems, DocumentObject)
	
	If NoUnfilledAttribute("Company", DocumentObject) Then
		Return;
	EndIf;

	CatalogPredefinedItems.Insert(
	"Company",
	CommonUseClientServer.PredefinedItem(
	"Catalog.Companies.MainCompany"));

EndProcedure
	
Procedure SupplementPredefinedDepartment(CatalogPredefinedItems, DocumentObject)
	
	If TypeOf(DocumentObject) = Type("DocumentObject.RetailReport") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute("Department", DocumentObject) Then
		Return;
	EndIf;
	
	CatalogPredefinedItems.Insert(
	"Department",
	CommonUseClientServer.PredefinedItem(
	"Catalog.StructuralUnits.MainDepartment"));

EndProcedure

Procedure SupplementPredefinedStructuralUnits(CatalogPredefinedItems, DocumentObject)
	
	If TypeOf(DocumentObject) = Type("DocumentObject.RetailReport") Then
		Return;
	EndIf;
	
	If Not NoUnfilledAttribute("StructuralUnit", DocumentObject) Then
		FillingRulesForStructuralUnit = New Map;
		ObjectFillingSBOverridable.OnDefiningRulesStructuralUnitsSettings(
		FillingRulesForStructuralUnit);
		
		PredefinedStructuralUnit = FillingRulesForStructuralUnit[TypeOf(DocumentObject)];
		
		If ValueIsFilled(PredefinedStructuralUnit) Then
			CatalogPredefinedItems.Insert(
			"StructuralUnit",
			PredefinedStructuralUnit);
		EndIf;
	EndIf;
	
	If Not NoUnfilledAttribute("StructuralUnitSales", DocumentObject) Then
		CatalogPredefinedItems.Insert(
		"StructuralUnitSales",
		CommonUseClientServer.PredefinedItem(
		"Catalog.StructuralUnits.MainDepartment"));
	EndIf;
	
	If Not NoUnfilledAttribute("StructuralUnitReserve", DocumentObject) Then
		CatalogPredefinedItems.Insert(
		"StructuralUnitReserve",
		CommonUseClientServer.PredefinedItem(
		"Catalog.StructuralUnits.MainWarehouse"));
	EndIf;

EndProcedure

Procedure SupplementPredefinedPriceKind(CatalogPredefinedItems, DocumentObject)
	
	If TypeOf(DocumentObject) = Type("DocumentObject.RetailReport") Then
		Return;
	EndIf;
	
	If TypeOf(DocumentObject) = Type("DocumentObject.ReceiptCR") Then
		Return;
	EndIf;
	
	Если TypeOf(DocumentObject) = Type("DocumentObject.ReceiptCRReturn") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute("PriceKind", DocumentObject) Then
		Return;
	EndIf;
	
	CatalogPredefinedItems.Insert(
	"PriceKind",
	CommonUseClientServer.PredefinedItem(
	"Catalog.PriceKinds.Wholesale"));
	
EndProcedure

#EndRegion

Procedure DeleteUnfilledValues(RenamedFields)
	
	For Each KeyAndValue In RenamedFields Do
		If ValueIsFilled(KeyAndValue.Value) Then
			Continue;
		EndIf;
		RenamedFields.Delete(KeyAndValue.Key);
	EndDo;

EndProcedure

#Region RenameEventFields
	
Procedure RenameEventFields(RenamedFields)
	
	If Not RenamedFields.Property("Event") Then
		Return;
	EndIf;
	
	RenameEventFieldsCounterparty(RenamedFields);
	RenameEventFieldsProject(RenamedFields);
	
EndProcedure

Procedure RenameEventFieldsCounterparty(RenamedFields)
	
	If RenamedFields.Property("Counterparty") Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT TOP 1
	|	EventParticipants.Contact AS Counterparty
	|FROM
	|	Document.Event.Parties AS EventParticipants
	|WHERE
	|	EventParticipants.Contact REFS Catalog.Counterparties
	|	AND EventParticipants.Ref = &Ref");
	Query.SetParameter("Ref", RenamedFields.Event);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		Selection.Next();
		RenamedFields.Insert("Counterparty", Selection.Counterparty);
	EndIf;
	
EndProcedure

Procedure RenameEventFieldsProject(RenamedFields)
	
	If Not GetFunctionalOption("ProjectManagement") Тогда
		Return;
	EndIf;
	
	If RenamedFields.Property("Project") Then
		Return;
	EndIf;
	
	Project = CommonUse.ObjectAttributeValue(RenamedFields.Event, "Project");
	If ValueIsFilled(Project) Then
		RenamedFields.Insert("Project", Project);
	EndIf;
	
EndProcedure

Procedure RenameFieldsCompany(RenamedFields, DocumentObject)
	
	If Not CommonUse.IsObjectAttribute(
		"Company",
		DocumentObject.Metadata()) Then
		Return;
	EndIf;
	
	Company = DocumentObject.Company;
	
	If Not ValueIsFilled(Company) Then
		RenamedFields.Property("Company", Company);
	EndIf;
	
	If Not ValueIsFilled(Company) Then
		Return;
	EndIf;
	
	RenameFieldsCompanyBankAccount(RenamedFields, DocumentObject, Company);
	RenameFieldsCompanyPettyCash(RenamedFields, DocumentObject, Company);
	RenameFieldsCompanyResponsiblePersons(RenamedFields, DocumentObject, Company);
	RenameFieldsCompanyVATTaxation(RenamedFields, DocumentObject, Company);
	
EndProcedure

Procedure RenameFieldsCompanyBankAccount(RenamedFields, DocumentObject, Company)
	
	If NoUnfilledAttribute("BankAccount", DocumentObject) Then
		Return;
	EndIf;
	
	If CommonUse.IsObjectAttribute("DocumentCurrency", DocumentObject.Metadata())
		And ValueIsFilled(DocumentObject.DocumentCurrency) Then
		CashCurrency = DocumentObject.DocumentCurrency;
	ElsIf CommonUse.IsObjectAttribute("CashCurrency", DocumentObject.Metadata())
		And ValueIsFilled(DocumentObject.CashCurrency) Then
		CashCurrency = DocumentObject.CashCurrency;
	EndIf;
	
	If Not ValueIsFilled(CashCurrency) Then
		RenamedFields.Property("DocumentCurrency", CashCurrency);
	EndIf;
	
	If Not ValueIsFilled(CashCurrency) Then
		RenamedFields.Property("CashCurrency", CashCurrency);
	EndIf;
	
	If Not ValueIsFilled(CashCurrency) Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	CASE
	|		WHEN Companies.BankAccountByDefault.CashCurrency = &CashCurrency
	|			THEN Companies.BankAccountByDefault
	|		ELSE UNDEFINED
	|	END AS BankAccount
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	Companies.Ref = &Company");
	Query.SetParameter("Company", Company);
	Query.SetParameter("CashCurrency", CashCurrency);
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	If Not ValueIsFilled(Selection.BankAccount) Then
		Return;
	EndIf;
	
	RenamedFields.Insert("BankAccount", Selection.BankAccount);
	
	If NoUnfilledAttribute("BankAccountPayee", DocumentObject) Then
		Return;
	EndIf;
	
	RenamedFields.Insert("BankAccountPayee", Selection.BankAccount);
	
EndProcedure

Procedure RenameFieldsCompanyPettyCash(RenamedFields, DocumentObject, Company)
	
	If NoUnfilledAttribute("PettyCash", DocumentObject) Then
		Return;
	EndIf;
	
	PettyCashByDefault = Catalogs.PettyCashes.GetPettyCashByDefault(Company);
	
	If Not ValueIsFilled(PettyCashByDefault) Then
		Return;
	EndIf;
	
	RenamedFields.Insert("PettyCash", PettyCashByDefault);
	
	If NoUnfilledAttribute("PettyCashPayee", DocumentObject) Then
		Return;
	EndIf;
	
	RenamedFields.Insert("PettyCashPayee", PettyCashByDefault);
	
EndProcedure

Procedure RenameFieldsCompanyResponsiblePersons(RenamedFields, DocumentObject, Company)
	
	If StrFind(DocumentObject.Metadata().FullName(), "Catalog") > 0 Then
		ResponsiblePersons = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(
		Company,
		CurrentSessionDate());
	Else
		ResponsiblePersons = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(
		Company,
		DocumentObject.Date);
	EndIf;
	
	FieldsMap = New Map;
	FieldsMap["Head"]				= "Head";
	FieldsMap["HeadPosition"]		= "HeadPositionRefs";
	FieldsMap["ChiefAccountant"]	= "ChiefAccountant";
	FieldsMap["LetOut"]				= "WarehouseMan";
	FieldsMap["LetOutPosition"]		= "WarehouseManPositionRef";
	
	For Each KeyAndValue In FieldsMap Do
		
		If NoUnfilledAttribute(KeyAndValue.Key, DocumentObject) Then
			Continue;
		EndIf;
		
		If Not ValueIsFilled(ResponsiblePersons[KeyAndValue.Value]) Then
			Continue;
		EndIf;
		
		RenamedFields.Insert(KeyAndValue.Key, ResponsiblePersons[KeyAndValue.Value]);
		
	EndDo;

EndProcedure

Procedure RenameFieldsCompanyVATTaxation(RenamedFields, DocumentObject, Company)
	
	If NoUnfilledAttribute("VATTaxation", DocumentObject) Then
		Return;
	EndIf;
	
	RenamedFields.Insert("VATTaxation",
	SmallBusinessServer.VATTaxation(
	Company,,
	CurrentSessionDate()));
	
EndProcedure

Процедура RenameFieldsCounterparty(RenamedFields)
	
	If Not RenamedFields.Property("Counterparty") Then
		Return;
	EndIf;
	
	CounterpartyDetails = CommonUse.ObjectAttributesValues(
	RenamedFields.Counterparty,
	"IsFolder, ContractByDefault");
	
	If CounterpartyDetails.IsFolder Then
		Raise NStr("ru = 'Нельзя выбирать группу контрагентов.'; en = 'You can not select a group of counterparties.'");
	EndIf;
	
	If RenamedFields.Property("Contract")
		And ValueIsFilled(RenamedFields.Contract)
		And RenamedFields.Counterparty = CommonUse.ObjectAttributesValues(
		RenamedFields.Contract,
		"Owner") Then
		
		Return;
		
	EndIf;
	
	RenamedFields.Insert("Contract", CounterpartyDetails.ContractByDefault);
	
EndProcedure

Procedure RenameFieldsContract(RenamedFields, DocumentObject)
	
	If Not RenamedFields.Property("Contract") Then
		Return;
	EndIf;
	
	ContractDetails = CommonUse.ObjectAttributesValues(
	RenamedFields.Contract,
	"SettlementsCurrency, PriceKind, CounterpartyPriceKind, DiscountMarkupKind");
	
	For Each KeyAndValue In ContractDetails Do
		
		If Not ValueIsFilled(KeyAndValue.Value) Then
			Continue;
		EndIf;
		
		For Each AttributeName In AttributeNames(KeyAndValue.Value, DocumentObject) Do
			RenamedFields.Insert(AttributeName, KeyAndValue.Value);
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure RenameFieldsDiscountCard(RenamedFields)
	
	If Not RenamedFields.Property("DiscountCard") Then
		Return;
	EndIf;
	
	RenamedFields.Insert(
	"DiscountPercentByDiscountCard",
	SmallBusinessServer.CalculateDiscountPercentByDiscountCard(
	CurrentSessionDate(),
	RenamedFields.DiscountCard));
	
EndProcedure

Procedure RenameFieldsStructuralUnit(RenamedFields, DocumentObject)
	
	If Not CommonUse.IsObjectAttribute("StructuralUnit", DocumentObject.Metadata()) Then
		Return;
	EndIf;
	
	StructuralUnit = DocumentObject.StructuralUnit;
	
	If Not ValueIsFilled(StructuralUnit) Then
		RenamedFields.Property("StructuralUnit", StructuralUnit);
	EndIf;
	
	If Not ValueIsFilled(StructuralUnit) Then
		Return;
	EndIf;
	
	StructuralUnitFieldsDescription = New Structure;
	StructuralUnitFieldsDescription.Insert("ProductsStructuralUnit", "TransferRecipient");
	StructuralUnitFieldsDescription.Insert("ProductsCell", "TransferRecipientCell");
	StructuralUnitFieldsDescription.Insert("InventoryStructuralUnit", "TransferSource");
	StructuralUnitFieldsDescription.Insert("CellInventory", "TransferSourceCell");
	StructuralUnitFieldsDescription.Insert("DisposalsStructuralUnit", "RecipientOfWastes");
	StructuralUnitFieldsDescription.Insert("DisposalsCell", "DisposalsRecipientCell");
	StructuralUnitFieldsDescription.Insert("StructuralUnitPayee", "TransferRecipient");
	StructuralUnitFieldsDescription.Insert("StructuralUnitReserve", "TransferSource");
	
	StructuralUnitData = CommonUse.ObjectAttributesValues(
	StructuralUnit,
	StructuralUnitFieldsDescription);
	
	For Each KeyAndValue In StructuralUnitData Do
		
		If NoUnfilledAttribute(KeyAndValue.Key, DocumentObject) Then
			Continue;
		EndIf;
		
		If ValueIsFilled(KeyAndValue.Value) Then
			RenamedFields.Вставить(KeyAndValue.Key, KeyAndValue.Value);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure RenameFieldsPriceKind(RenamedFields)
	
	If Not RenamedFields.Property("PriceKind") Then
		Return;
	EndIf;
	
	RenamedFields.Insert(
	"AmountIncludesVAT",
	CommonUse.ObjectAttributeValue(
	RenamedFields.PriceKind,
	"PriceIncludesVAT"));
	
EndProcedure

Procedure RenameFieldsCurrency(RenamedFields)
	
	For Each KeyAndValue In RenamedFields Do
		
		If TypeOf(KeyAndValue.Value) <> Type("CatalogRef.Currencies") Then
			Continue;
		EndIf;
		
		CommonUseClientServer.ExpandStructure(
		RenamedFields,
		InformationRegisters.CurrencyRates.GetLast(,
		New Structure("Currency", KeyAndValue.Value)),
		True);
		
		Break;
		
	EndDo;
	
EndProcedure

#EndRegion

Function StructuralUnitTypeToChoiceParameters(StructuralUnitType, ChoiceParameters)
	
	For Each ChoiceParameter In ChoiceParameters Do
		
		If ChoiceParameter.Name <> "Filter.StructuralUnitType" Then
			Continue;
		EndIf;
		
		If TypeOf(ChoiceParameter.Value) = Type("FixedArray") Then
			For Each ParameterValue In ChoiceParameter.Value Do
				If StructuralUnitType = ParameterValue Then
					Return True;
				EndIf; 
			EndDo;
		ElsIf TypeOf(ChoiceParameter.Value) = Type("EnumRef.StructuralUnitsTypes") 
			And StructuralUnitType = ChoiceParameter.Value Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction 

Function NoUnfilledAttribute(AttributeName, DocumentObject)
	
	If Not CommonUse.IsObjectAttribute(
		AttributeName,
		DocumentObject.Metadata()) Then
		Return True;
	EndIf;
	
	Return ValueIsFilled(DocumentObject[AttributeName]);
	
EndFunction

Function AttributeNames(Value, DocumentObject)
	
	Result = New Array;
	
	For Each Attribute In DocumentObject.Ref.Metadata().Attributes Do
		
		If Attribute.Type.ContainsType(TypeOf(Value)) Then
			Result.Add(Attribute.Name);
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

Procedure FillTabularSections(DocumentObject, FillingData)
	
	For Each TabularSection In DocumentObject.Metadata().TabularSections Do
		
		If Not FillingData.Property(TabularSection.Name) Then
			Continue;
		EndIf;

		If DocumentObject[TabularSection.Name].Count()>0 Then
			Continue;
		EndIf;
		
		For Each FillingRow In FillingData[TabularSection.Name] Do
			NewTabularSectionRow = DocumentObject[TabularSection.Name].Add();
			FillPropertyValues(NewTabularSectionRow, FillingRow);
			WorkWithProductsServer.FillDataInTabularSectionRow(DocumentObject, TabularSection.Name, NewTabularSectionRow);
		EndDo;
		
	EndDo;

EndProcedure

#EndRegion