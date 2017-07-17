#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Function generates the structure of
// the Return value available rules table:
//  ValueTable - Columns:
//  	1. Name							- is a
//  	rule identifier, 2. DynamicRuleKey		- additional identifier for rights generated automatically (for example, Additional attributes,
//  	contact information kinds), 3 IsFolder					- shows that this rule is not used
//  	in the settings, 4. Presentation				- user presentation
//  	of a rule, 5. MultipleUse	- shows that several values
//  	can be specified, 6. AvailableComparisonTypes		- values list of the DataLayoutComparisonType type - comparison kinds used
//  	for rule, 7. ComparisonType					- default comparison
//  	kind, 8. ValueProperties				- properties of form field item (table columns) connected to specified comparison values.
Function RulesDescription() Export
	
	Rules = New ValueTree;
	Rules.Columns.Add("Name",							New TypeDescription("String", New StringQualifiers(50)));
	Rules.Columns.Add("DynamicRuleKey",	New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation,CatalogRef.ContactInformationKinds"));
	Rules.Columns.Add("Presentation",				New TypeDescription("String", New StringQualifiers(100)));
	Rules.Columns.Add("IsFolder",					New TypeDescription("Boolean"));
	Rules.Columns.Add("MultipleUse",	New TypeDescription("Boolean"));
	Rules.Columns.Add("AvailableComparisonTypes",		New TypeDescription("ValueList"));
	Rules.Columns.Add("ComparisonType",				New TypeDescription("DataCompositionComparisonType"));
	Rules.Columns.Add("ValueProperties",			New TypeDescription("Structure"));
	
	Return Rules;
	
EndFunction

// Function - Receive available
// rules of the Return value filter:
//  ValueTable - For the description of the table fields, see a comment to the RulesDescription() function
Function GetAvailableFilterRules() Export
	
	Rules = RulesDescription();
	
	TypeDescriptionRow				= New TypeDescription("String",,,,New StringQualifiers(100));
	CurrencyTypeDescription			= New TypeDescription("Number",,,New NumberQualifiers(15,2));
	TypeDescriptionStandardDate		= New TypeDescription("StandardBeginningDate");
	TypeDescriptionStandardPeriod	= New TypeDescription("StandardPeriod");
	
	#Region CounterpartyAttributes
	
	CounterpartyPropertiesGroup = Rules.Rows.Add();
	CounterpartyPropertiesGroup.Name = "CounterpartyAttributes";
	CounterpartyPropertiesGroup.Presentation = NStr("en='Attributes (main, additional)';ru='Реквизиты (основные, дополнительные)'");
	CounterpartyPropertiesGroup.IsFolder = True;
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "Tag";
	NewRule.Presentation = NStr("en='Tag';ru='Тег'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.Tags"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal,NotEqual,InList,NotInList");
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "CounterpartyKind";
	NewRule.Presentation = Metadata.Catalogs.Counterparties.Attributes.LegalEntityIndividual.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("EnumRef.CounterpartyKinds"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal");
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "Group";
	NewRule.Presentation = Metadata.Catalogs.Counterparties.StandardAttributes.Parent.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.Counterparties"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Folders);
	AddComparisonTypes(NewRule, "Equal,NotEqual,InHierarchy,NotInHierarchy,InList,NotInList", 3);
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "CreationDate";
	NewRule.Presentation = Metadata.Catalogs.Counterparties.Attributes.CreationDate;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardDate);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 4);
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "Comment";
	NewRule.Presentation = Metadata.Catalogs.Counterparties.Attributes.Comment;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionRow);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "BeginsWith,NotBeginsWith,Contains,NotContains", 3);
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "Responsible";
	NewRule.Presentation = Metadata.Catalogs.Counterparties.Attributes.Responsible.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.Employees"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal,NotEqual,InList,NotInList,InGroup,NotInGroup,Filled,NotFilled");
	
	#EndRegion
	
	#Region AdditionalAttributes
	
	If GetFunctionalOption("UseAdditionalAttributesAndInformation") Then
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	AdditionalAttributesAndInformation.Ref,
			|	AdditionalAttributesAndInformation.Title,
			|	AdditionalAttributesAndInformation.ValueType,
			|	AdditionalAttributesAndInformation.FormatProperties
			|FROM
			|	ChartOfCharacteristicTypes.AdditionalAttributesAndInformation AS AdditionalAttributesAndInformation
			|WHERE
			|	AdditionalAttributesAndInformation.DeletionMark = FALSE
			|	AND AdditionalAttributesAndInformation.ThisIsAdditionalInformation = FALSE
			|	AND AdditionalAttributesAndInformation.PropertySet = VALUE(Catalog.AdditionalAttributesAndInformationSets.Catalog_Counterparties)
			|
			|ORDER BY
			|	AdditionalAttributesAndInformation.Title";
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			NewRule = CounterpartyPropertiesGroup.Rows.Add();
			NewRule.Name = "AdditionalAttribute";
			NewRule.DynamicRuleKey = Selection.Ref;
			NewRule.IsFolder = False;
			NewRule.MultipleUse = False;
			NewRule.Presentation = Selection.Title;
			NewRule.ValueProperties.Insert("TypeRestriction", Selection.ValueType);
			NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Items);
			NewRule.ValueProperties.Insert("Format", Selection.FormatProperties);
			AddComparisonTypes(NewRule, "Equal,NotEqual");
			If Selection.ValueType.ContainsType(Type("Number")) Or Selection.ValueType.ContainsType(Type("Date")) Then
				AddComparisonTypes(NewRule, "Greater,GreaterOrEqual,Less,LessOrEqual");
				NewRule.MultipleUse = True;
			EndIf;
			If Selection.ValueType.ContainsType(Type("String")) Then
				AddComparisonTypes(NewRule, "BeginsWith,NotBeginsWith,Contains,NotContains");
			EndIf;
			For Each ValueType IN Selection.ValueType.Types() Do
				If CommonUse.IsReference(ValueType) Then
					AddComparisonTypes(NewRule, "InList,NotInList,Filled,NotFilled");
					Break;
				EndIf;
			EndDo;
			
		EndDo;
		
	EndIf;
	
	#EndRegion
	
	#Region ContactInformation
	
	GroupContactInformation = Rules.Rows.Add();
	GroupContactInformation.Name = "CounterpartyContactInformation";
	GroupContactInformation.Presentation = NStr("en='Addresses (geography)';ru='Адреса (география)'");
	GroupContactInformation.IsFolder = True;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ContactInformationKinds.Type,
	|	ContactInformationKinds.Ref,
	|	ContactInformationKinds.Description
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|WHERE
	|	ContactInformationKinds.DeletionMark = FALSE
	|	AND ContactInformationKinds.Parent = VALUE(Catalog.ContactInformationKinds.CatalogCounterparties)
	|
	|ORDER BY
	|	ContactInformationKinds.AdditionalOrderingAttribute";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If Selection.Type = Enums.ContactInformationTypes.Address Then
			
			RuleAddress = GroupContactInformation.Rows.Add();
			RuleAddress.Name = "ContactInformationKindPresentation";
			RuleAddress.DynamicRuleKey = Selection.Ref;
			RuleAddress.IsFolder = False;
			RuleAddress.MultipleUse = False;
			RuleAddress.Presentation = Selection.Description;
			RuleAddress.ValueProperties.Insert("TypeRestriction", TypeDescriptionRow);
			RuleAddress.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
			AddComparisonTypes(RuleAddress, "BeginsWith,NotBeginsWith,Contains,NotContains", 3);
			
			NewRule = RuleAddress.Rows.Add();
			NewRule.Name = "ContactInformationKindCountry";
			NewRule.DynamicRuleKey = Selection.Ref;
			NewRule.IsFolder = False;
			NewRule.MultipleUse = False;
			NewRule.Presentation = NStr("en='Country';ru='Страна'") + " (" + Lower(RuleAddress.Presentation) + ")";
			NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionRow);
			NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
			AddComparisonTypes(NewRule, "BeginsWith,NotBeginsWith,Contains,NotContains", 3);
			
			NewRule = RuleAddress.Rows.Add();
			NewRule.Name = "ContactInformationKindState";
			NewRule.DynamicRuleKey = Selection.Ref;
			NewRule.IsFolder = False;
			NewRule.MultipleUse = False;
			NewRule.Presentation = NStr("en='Region';ru='Регион'") + " (" + Lower(RuleAddress.Presentation) + ")";
			NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionRow);
			NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
			AddComparisonTypes(NewRule, "BeginsWith,NotBeginsWith,Contains,NotContains", 3);
			
			NewRule = RuleAddress.Rows.Add();
			NewRule.Name = "ContactInformationKindCity";
			NewRule.DynamicRuleKey = Selection.Ref;
			NewRule.IsFolder = False;
			NewRule.MultipleUse = False;
			NewRule.Presentation = NStr("en='City';ru='Город'") + " (" + Lower(RuleAddress.Presentation) + ")";
			NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionRow);
			NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
			AddComparisonTypes(NewRule, "BeginsWith,NotBeginsWith,Contains,NotContains", 3);
			
		Else
			
			NewRule = GroupContactInformation.Rows.Add();
			NewRule.Name = "ContactInformationKindPresentation";
			NewRule.DynamicRuleKey = Selection.Ref;
			NewRule.IsFolder = False;
			NewRule.MultipleUse = False;
			NewRule.Presentation = Selection.Description;
			NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionRow);
			NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
			AddComparisonTypes(NewRule, "BeginsWith,NotBeginsWith,Contains,NotContains", 3);
			
		EndIf;
		
	EndDo;
	
	#EndRegion
	
	#Region Events
	
	EventGroup = Rules.Rows.Add();
	EventGroup.Name = "Events";
	EventGroup.Presentation = NStr("en='Events (remoteness, quantity)';ru='События (давность, количество)'");
	EventGroup.IsFolder = True;
	
	NewRule = EventGroup.Rows.Add();
	NewRule.Name = "EventsDateLast";
	NewRule.Presentation = NStr("en='Last event date';ru='Дата последнего события'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardDate);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 5);
	
	RuleEventsQuantity = EventGroup.Rows.Add();
	RuleEventsQuantity.Name = "EventsQuantity";
	RuleEventsQuantity.Presentation = NStr("en='Number of events';ru='Количество событий'");
	RuleEventsQuantity.IsFolder = False;
	RuleEventsQuantity.MultipleUse = True;
	RuleEventsQuantity.ValueProperties.Insert("TypeRestriction", New TypeDescription("Number"));
	RuleEventsQuantity.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(RuleEventsQuantity, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 3);
	
	NewRule = RuleEventsQuantity.Rows.Add();
	NewRule.Name = "EventsQuantityPeriod";
	NewRule.Presentation = NStr("en='For period';ru='По периоду'") + " (" + Lower(RuleEventsQuantity.Presentation) + ")";
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardPeriod);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal");
	
	GroupAdditional = EventGroup.Rows.Add();
	GroupAdditional.Name = "EventsAdditionally";
	GroupAdditional.Presentation = NStr("en='Event clarifications';ru='Уточнения событий'");
	GroupAdditional.IsFolder = True;
	
	NewRule = GroupAdditional.Rows.Add();
	NewRule.Name = "EventsState";
	NewRule.Presentation = NStr("en='Event state';ru='Состояние событий'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.EventStates"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal,NotEqual,InList,NotInList");
	
	NewRule = GroupAdditional.Rows.Add();
	NewRule.Name = "EventsEventType";
	NewRule.Presentation = NStr("en='Event type';ru='Тип события'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("EnumRef.EventTypes"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal,NotEqual,InList,NotInList");
	
	#EndRegion
	
	#Region CustomerOrders
	
	GroupOrders = Rules.Rows.Add();
	GroupOrders.Name = "CustomerOrders";
	GroupOrders.Presentation = NStr("en='Customer orders (remoteness, quantity)';ru='Заказы покупателей (давность, количество)'");
	GroupOrders.IsFolder = True;
	
	NewRule = GroupOrders.Rows.Add();
	NewRule.Name = "CustomerOrdersDateLast";
	NewRule.Presentation = NStr("en='Last order date';ru='Дата последнего заказа'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardDate);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 5);
	
	RuleOrdersQuantity = GroupOrders.Rows.Add();
	RuleOrdersQuantity.Name = "CustomerOrdersQuantity";
	RuleOrdersQuantity.Presentation = NStr("en='Number of orders';ru='Количество заказов'");
	RuleOrdersQuantity.IsFolder = False;
	RuleOrdersQuantity.MultipleUse = True;
	RuleOrdersQuantity.ValueProperties.Insert("TypeRestriction", New TypeDescription("Number"));
	RuleOrdersQuantity.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(RuleOrdersQuantity, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 3);
	
	NewRule = RuleOrdersQuantity.Rows.Add();
	NewRule.Name = "CustomerOrdersQuantityPeriod";
	NewRule.Presentation = NStr("en='For period';ru='По периоду'") + " (" + Lower(RuleOrdersQuantity.Presentation) + ")";
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardPeriod);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal");
	
	GroupAdditional = GroupOrders.Rows.Add();
	GroupAdditional.Name = "CustomerOrdersAdditionally";
	GroupAdditional.Presentation = NStr("en='Clarifications of customer orders';ru='Уточнения заказов покупателей'");
	GroupAdditional.IsFolder = True;
	
	NewRule = GroupAdditional.Rows.Add();
	NewRule.Name = "CustomerOrdersOrderState";
	NewRule.Presentation = NStr("en='State of customer orders';ru='Состояние заказов покупателя'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.CustomerOrderStates"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal,NotEqual,InList,NotInList");
	
	#EndRegion
	
	#Region InvoicesForPayment
	
	Account_sGroup = Rules.Rows.Add();
	Account_sGroup.Name = "InvoicesForPayment";
	Account_sGroup.Presentation = NStr("en='Proforma invoices (issue date, quantity)';ru='Счета на оплату (давность, количество)'");
	Account_sGroup.IsFolder = True;
	
	NewRule = Account_sGroup.Rows.Add();
	NewRule.Name = "InvoicesForPaymentLastDate";
	NewRule.Presentation = NStr("en='Last account date';ru='Дата последнего счета'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardDate);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 5);
	
	RuleAccountsQuantity = Account_sGroup.Rows.Add();
	RuleAccountsQuantity.Name = "InvoicesForPaymentQuantity";
	RuleAccountsQuantity.Presentation = NStr("en='Number of accounts';ru='Количество счетов'");
	RuleAccountsQuantity.IsFolder = False;
	RuleAccountsQuantity.MultipleUse = True;
	RuleAccountsQuantity.ValueProperties.Insert("TypeRestriction", New TypeDescription("Number"));
	RuleAccountsQuantity.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(RuleAccountsQuantity, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 3);
	
	NewRule = RuleAccountsQuantity.Rows.Add();
	NewRule.Name = "InvoicesForPaymentQuantityPeriod";
	NewRule.Presentation = NStr("en='For period';ru='По периоду'") + " (" + Lower(RuleAccountsQuantity.Presentation) + ")";
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardPeriod);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal");
	
	#EndRegion
	
	#Region SalesProductsAndServices
	
	GroupSalesProductsAndServices = Rules.Rows.Add();
	GroupSalesProductsAndServices.Name = "SalesProductsAndServices";
	GroupSalesProductsAndServices.Presentation = NStr("en='Sales (products and services)';ru='Продажи (номенклатура)'");
	GroupSalesProductsAndServices.IsFolder = True;
	
	NewRule = GroupSalesProductsAndServices.Rows.Add();
	NewRule.Name = "SalesProductsAndServicesProductsAndServices";
	NewRule.Presentation = NStr("en='ProductAndServices';ru='ProductAndServices'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.ProductsAndServices"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Items);
	AddComparisonTypes(NewRule, "Equal,NotEqual,InList,NotInList");
	
	NewRule = GroupSalesProductsAndServices.Rows.Add();
	NewRule.Name = "SalesProductsAndServicesProductsAndServicesGroup";
	NewRule.Presentation = NStr("en='Products and services group';ru='Группа номенклатуры'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.ProductsAndServices"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Folders);
	AddComparisonTypes(NewRule, "Equal,NotEqual,InHierarchy,NotInHierarchy,InList,NotInList");
	
	NewRule = GroupSalesProductsAndServices.Rows.Add();
	NewRule.Name = "SalesProductsAndServicesProductsAndServicesCategory";
	NewRule.Presentation = NStr("en='Products and services group';ru='Номенклатурная группа'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.ProductsAndServicesCategories"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Items);
	AddComparisonTypes(NewRule, "Equal,NotEqual,InHierarchy,NotInHierarchy,InList,NotInList");
	
	GroupAdditional = GroupSalesProductsAndServices.Rows.Add();
	GroupAdditional.Name = "SalesProductsAndServicesAdditionally";
	GroupAdditional.Presentation = NStr("en='Sales clarification by products and services';ru='Уточнения продаж по номенклатуре'");
	GroupAdditional.IsFolder = True;
	
	NewRule = GroupAdditional.Rows.Add();
	NewRule.Name = "SalesProductsAndServicesPeriod";
	NewRule.Presentation = NStr("en='For the period (sales by products and services)';ru='За период (продажи по номенклатуре)'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardPeriod);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal");
	
	#EndRegion
	
	#Region SalesIncome
	
	GroupSalesIncome = Rules.Rows.Add();
	GroupSalesIncome.Name = "SalesIncome";
	GroupSalesIncome.Presentation = NStr("en='Sales (revenue, profit)';ru='Продажи (выручка, прибыль)'");
	GroupSalesIncome.IsFolder = True;
	
	NewRule = GroupSalesIncome.Rows.Add();
	NewRule.Name = "SalesIncomeIncome";
	NewRule.Presentation = NStr("en='Revenue (man. currency)';ru='Выручка (упр. валюте)'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", CurrencyTypeDescription);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 4);
	
	NewRule = GroupSalesIncome.Rows.Add();
	NewRule.Name = "SalesIncomeGrossProfit";
	NewRule.Presentation = NStr("en='Gross profit (man. currency)';ru='Валовая прибыль (упр. валюте)'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", CurrencyTypeDescription);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 4);
	
	GroupAdditional = GroupSalesIncome.Rows.Add();
	GroupAdditional.Name = "SalesIncomeAdditionally";
	GroupAdditional.Presentation = NStr("en='Clarifications of revenue from sales';ru='Уточнения выручки от продаж'");
	GroupAdditional.IsFolder = True;
	
	NewRule = GroupAdditional.Rows.Add();
	NewRule.Name = "SalesIncomePeriod";
	NewRule.Presentation = NStr("en='For a period (revenue from sales)';ru='За период (выручка от продаж)'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardPeriod);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal");
	
	#EndRegion
	
	#Region Debt
	
	GroupDebt = Rules.Rows.Add();
	GroupDebt.Name = "Debt";
	GroupDebt.Presentation = NStr("en='Debt (debt, overdue)';ru='Задолженность (долг, просрочка)'");
	GroupDebt.IsFolder = True;
	
	NewRule = GroupDebt.Rows.Add();
	NewRule.Name = "CustomerDebtAmount";
	NewRule.Presentation = NStr("en='Amount of customer debt (man. currency)';ru='Сумма долга покупателя (упр. валюте)'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", CurrencyTypeDescription);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 4);
	
	NewRule = GroupDebt.Rows.Add();
	NewRule.Name = "CustomerDebtTerm";
	NewRule.Presentation = NStr("en='Customer overdue period (days)';ru='Срок просрочки покупателя (дней)'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("Number"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual");
	
	NewRule = GroupDebt.Rows.Add();
	NewRule.Name = "VendorDebtAmount";
	NewRule.Presentation = NStr("en='Amount of debt to supplier (man. currency)';ru='Сумма долга поставщику (упр. валюте)'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", CurrencyTypeDescription);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 4);
	
	NewRule = GroupDebt.Rows.Add();
	NewRule.Name = "VendorDebtTerm";
	NewRule.Presentation = NStr("en='Supplier overdue period (days)';ru='Срок просрочки поставщику (дней)'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("Number"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual");
	
	#EndRegion
	
	Return Rules;
	
EndFunction

// Function returns the segment content
//
// Parameters:
//  Segment	 - CatalogRef.Segment	 - segment for which it
// is required to receive the Return value content:
//  Array - array of counterparties included in segment
Function GetSegmentComposition(Segment) Export
	
	Query = GenerateQueryOnRules(Segment);
	CounterpartiesArray = Query.Execute().Unload().UnloadColumn("Ref");
	
	Return CounterpartiesArray;
	
EndFunction

// Function - Generate query by rules
//
// Parameters:
//  Segment	 - CatalogRef.Segment	 - segment for which it
// is required to receive the Return value query:
//  Query - query with a set text and parameters
Function GenerateQueryOnRules(Segment) Export
	
	UsedAdditAttributes = GetFunctionalOption("UseAdditionalAttributesAndInformation");
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	SegmentsUsedRules.Name,
		|	SegmentsUsedRules.Settings,
		|	SegmentsUsedRules.DynamicRuleKey
		|FROM
		|	Catalog.Segments.UsedRules AS SegmentsUsedRules
		|WHERE
		|	SegmentsUsedRules.Ref = &Ref
		|
		|ORDER BY
		|	SegmentsUsedRules.LineNumber";
	
	Query.SetParameter("Ref", Segment);
	RulesSelection = Query.Execute().Select();
	
	Query = New Query;
	
	QuerySchema = New QuerySchema;
	QuerySchema.SetQueryText("
		|SELECT ALLOWED DISTINCT
		|	Counterparties.Ref
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.IsFolder = FALSE
		|	AND Counterparties.DeletionMark = FALSE
		|
		|ORDER BY
		|	Counterparties.Description");
	
	AvailableTableCounterparties = QuerySchema.QueryBatch[0].AvailableTables.Find("Catalog.Counterparties");
	Operator = QuerySchema.QueryBatch[0].Operators[0];
	FilterQuery = Operator.Filter;
	
	RuleNumber = 0;
	
	While RulesSelection.Next() Do
		
		RuleNumber = RuleNumber + 1;
		RuleSettings = RulesSelection.Settings.Get();
		
		If RulesSelection.Name = "Tag" Then
			
			FilterQuery.Add(ComparisonCondition("Counterparties.Tags.Tag", RuleSettings.ComparisonType, RulesSelection.Name));
			Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			
		ElsIf RulesSelection.Name = "CounterpartyKind" Then
			
			FilterQuery.Add("Counterparties.LegalEntityIndividual = & CounterpartiesKind");
			Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			
		ElsIf RulesSelection.Name = "Group" Then
			
			FilterQuery.Add(ComparisonCondition("Counterparties.Parent", RuleSettings.ComparisonType, RulesSelection.Name));
			Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			
		ElsIf RulesSelection.Name = "CreationDate" Then
			
			FilterQuery.Add(ComparisonCondition("Counterparties.CreationDate", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
			Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value.Date);
			
		ElsIf RulesSelection.Name = "Comment" Then
			
			FilterQuery.Add(ComparisonCondition("Counterparties.Comment", RuleSettings.ComparisonType, RulesSelection.Name));
			Query.SetParameter(RulesSelection.Name, OperatorTemplateDetails(RuleSettings.ComparisonType, RuleSettings.Value));
			
		ElsIf RulesSelection.Name = "Responsible" Then
			
			FilterQuery.Add(ComparisonCondition("Counterparties.Responsible", RuleSettings.ComparisonType, RulesSelection.Name));
			Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			
		ElsIf RulesSelection.Name = "AdditionalAttribute" AND UsedAdditAttributes AND ValueIsFilled(RulesSelection.DynamicRuleKey) Then
			
			If SmallBusinessServer.FindQuerySchemaSource(Operator.Sources, "CounterpartiesAdditionalAttributes") = Undefined Then
				AvailableAdditAttributesTable = SmallBusinessServer.FindAvailableTableQuerySchemaField(AvailableTableCounterparties, "AdditionalAttributes", Type("QuerySchemaAvailableNestedTable"));
				NewSource = Operator.Sources.Add(AvailableAdditAttributesTable, "CounterpartiesAdditionalAttributes");
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("CounterpartiesAdditionalAttributes", "Counterparties.Ref = CounterpartiesAdditionalAttributes.Ref");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.Inner;
			EndIf;
			
			FilterQuery.Add("CounterpartiesAdditionalAttributes.Property = & Property" + RuleNumber);
			Query.SetParameter("Property" + RuleNumber, RulesSelection.DynamicRuleKey);
			FilterQuery.Add(ComparisonCondition("CounterpartiesAdditionalAttributes.Value", RuleSettings.ComparisonType, "ValueAdditionalAttribute" + RuleNumber));
			If TypeOf(RuleSettings.Value) = Type("String") AND
				(RuleSettings.ComparisonType = DataCompositionComparisonType.BeginsWith Or RuleSettings.ComparisonType = DataCompositionComparisonType.NotBeginsWith
				Or RuleSettings.ComparisonType = DataCompositionComparisonType.Contains Or RuleSettings.ComparisonType = DataCompositionComparisonType.NotContains) Then
					Query.SetParameter("ValueAdditionalAttribute" + RuleNumber, OperatorTemplateDetails(RuleSettings.ComparisonType, RuleSettings.Value));
			Else
				Query.SetParameter("ValueAdditionalAttribute" + RuleNumber, RuleSettings.Value);
			EndIf;
			
		ElsIf Left(RulesSelection.Name, 23) = "ContactInformationKind" AND ValueIsFilled(RulesSelection.DynamicRuleKey) Then
			
			If SmallBusinessServer.FindQuerySchemaSource(Operator.Sources, "CounterpartiesContactInformation") = Undefined Then
				AvailableCITable = SmallBusinessServer.FindAvailableTableQuerySchemaField(AvailableTableCounterparties, "ContactInformation", Type("QuerySchemaAvailableNestedTable"));
				NewSource = Operator.Sources.Add(AvailableCITable, "CounterpartiesContactInformation");
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("CounterpartiesContactInformation", "Counterparties.Ref = CounterpartiesContactInformation.Ref");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.Inner;
			EndIf;
			
			FilterQuery.Add("CounterpartiesContactInformation.Type = & CIKind" + RuleNumber);
			Query.SetParameter("CIKind" + RuleNumber, RulesSelection.DynamicRuleKey);
			FilterQuery.Add(ComparisonCondition("CounterpartiesContactInformation." + Mid(RulesSelection.Name, 24), RuleSettings.ComparisonType, "ValueCI" + RuleNumber));
			Query.SetParameter("ValueCI" + RuleNumber, OperatorTemplateDetails(RuleSettings.ComparisonType, RuleSettings.Value));
			
		ElsIf Left(RulesSelection.Name, 7) = "Events" Then
			
			NewSource = SmallBusinessServer.FindQuerySchemaSource(Operator.Sources, "EventsForPeriod");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "EventsForPeriod");
				NewSource.Source.Query.SetQueryText("SELECT ALLOWED
				                                    |	EventParticipants.Contact AS Counterparty,
				                                    |	COUNT(DISTINCT EventParticipants.Ref) AS EventsCount,
				                                    |	MAX(EventParticipants.Ref.Date) AS LastEventDate
				                                    |FROM
				                                    |	Document.Event.Participants AS EventParticipants
				                                    |WHERE
				                                    |	EventParticipants.Ref.DeletionMark = FALSE
				                                    |	AND EventParticipants.Contact REFS Catalog.Counterparties
				                                    |
				                                    |GROUP BY
				                                    |	EventParticipants.Contact");
				
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("EventsForPeriod", "Counterparties.Ref = EventsForPeriod.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.LeftOuter;
				
			EndIf;
			
			InsertedQueryFilter = NewSource.Source.Query.Operators[0].Filter;
			
			If RulesSelection.Name = "EventsDateLast" Then
				FilterQuery.Add(ComparisonCondition("ISNULL(EventsForPeriod.LastEventDate, DATETIME(0001,01,01))", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value.Date);
			ElsIf RulesSelection.Name = "EventsQuantity" Then
				FilterQuery.Add(ComparisonCondition("ISNULL(EventsForPeriod.EventsQuantity, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			ElsIf RulesSelection.Name = "EventsQuantityPeriod" Then
				If ValueIsFilled(RuleSettings.Value.StartDate) Then
					InsertedQueryFilter.Add(ComparisonCondition("EventParties.Ref.Date", DataCompositionComparisonType.GreaterOrEqual, RulesSelection.Name + "Begin"));
					Query.SetParameter(RulesSelection.Name + "Begin", RuleSettings.Value.StartDate);
				EndIf;
				If ValueIsFilled(RuleSettings.Value.EndDate) Then
					InsertedQueryFilter.Add(ComparisonCondition("EventParties.Ref.Date", DataCompositionComparisonType.LessOrEqual, RulesSelection.Name + "End"));
					Query.SetParameter(RulesSelection.Name + "End",  RuleSettings.Value.EndDate);
				EndIf;
			ElsIf RulesSelection.Name = "EventsState" Then
				InsertedQueryFilter.Add(ComparisonCondition("EventParties.Ref.Status", RuleSettings.ComparisonType, RulesSelection.Name));
				Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			ElsIf RulesSelection.Name = "EventsEventType" Then
				InsertedQueryFilter.Add(ComparisonCondition("EventParties.Ref.EventType", RuleSettings.ComparisonType, RulesSelection.Name));
				Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			EndIf;
			
		ElsIf Left(RulesSelection.Name, 17) = "CustomerOrders" Then
			
			NewSource = SmallBusinessServer.FindQuerySchemaSource(Operator.Sources, "OrdersForPeriod");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "OrdersForPeriod");
				NewSource.Source.Query.SetQueryText("
					|SELECT ALLOWED
					|	CustomerOrder.Counterparty,
					|	COUNT(CustomerOrder.Ref) AS OrdersQuantity,
					|	MAX(CustomerOrder.Date) AS LastOrderDate
					|FROM
					|	Document.CustomerOrder AS CustomerOrder
					|WHERE
					|	CustomerOrder.Posted = TRUE
					|
					|GROUP BY
					|	CustomerOrder.Counterparty");
				
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("OrdersForPeriod", "Counterparties.Ref = OrdersForPeriod.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.LeftOuter;
				
			EndIf;
			
			InsertedQueryFilter = NewSource.Source.Query.Operators[0].Filter;
			
			If RulesSelection.Name = "CustomerOrdersDateLast" Then
				FilterQuery.Add(ComparisonCondition("ISNULL(OrdersForPeriod.LastOrderDate, DATETIME(0001,01,01))", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value.Date);
			ElsIf RulesSelection.Name = "CustomerOrdersQuantity" Then
				FilterQuery.Add(ComparisonCondition("ISNULL(OrdersForPeriod.OrdersQuantity, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			ElsIf RulesSelection.Name = "CustomerOrdersQuantityPeriod" Then
				If ValueIsFilled(RuleSettings.Value.StartDate) Then
					InsertedQueryFilter.Add(ComparisonCondition("CustomerOrder.Date", DataCompositionComparisonType.GreaterOrEqual, RulesSelection.Name + "Begin"));
					Query.SetParameter(RulesSelection.Name + "Begin", RuleSettings.Value.StartDate);
				EndIf;
				If ValueIsFilled(RuleSettings.Value.EndDate) Then
					InsertedQueryFilter.Add(ComparisonCondition("CustomerOrder.Date", DataCompositionComparisonType.LessOrEqual, RulesSelection.Name + "End"));
					Query.SetParameter(RulesSelection.Name + "End",  RuleSettings.Value.EndDate);
				EndIf;
			ElsIf RulesSelection.Name = "CustomerOrdersOrderState" Then
				InsertedQueryFilter.Add(ComparisonCondition("CustomerOrder.OrderState", RuleSettings.ComparisonType, RulesSelection.Name));
				Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			EndIf;
			
		ElsIf Left(RulesSelection.Name, 13) = "InvoicesForPayment" Then
			
			NewSource = SmallBusinessServer.FindQuerySchemaSource(Operator.Sources, "AccountsForPeriod");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "AccountsForPeriod");
				NewSource.Source.Query.SetQueryText("
					|SELECT ALLOWED
					|	InvoiceForPayment.Counterparty,
					|	COUNT(InvoiceForPayment.Ref) AS AccountsQuantity,
					|	MAX(InvoiceForPayment.Date) AS LastAccountDate
					|FROM
					|	Document.InvoiceForPayment AS InvoiceForPayment
					|WHERE
					|	InvoiceForPayment.Posted = TRUE
					|
					|GROUP BY
					|	InvoiceForPayment.Counterparty");
				
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("AccountsForPeriod", "Counterparties.Ref = AccountsForPeriod.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.LeftOuter;
				
			EndIf;
			
			InsertedQueryFilter = NewSource.Source.Query.Operators[0].Filter;
			
			If RulesSelection.Name = "InvoicesForPaymentLastDate" Then
				FilterQuery.Add(ComparisonCondition("ISNULL(AccountsForPeriod.LastAccountDate, DATETIME(0001,01,01))", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value.Date);
			ElsIf RulesSelection.Name = "InvoicesForPaymentQuantity" Then
				FilterQuery.Add(ComparisonCondition("ISNULL(AccountsForPeriod.AccountsQuantity, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			ElsIf RulesSelection.Name = "InvoicesForPaymentQuantityPeriod" Then
				If ValueIsFilled(RuleSettings.Value.StartDate) Then
					InsertedQueryFilter.Add(ComparisonCondition("InvoiceForPayment.Date", DataCompositionComparisonType.GreaterOrEqual, RulesSelection.Name + "Begin"));
					Query.SetParameter(RulesSelection.Name + "Begin", RuleSettings.Value.StartDate);
				EndIf;
				If ValueIsFilled(RuleSettings.Value.EndDate) Then
					InsertedQueryFilter.Add(ComparisonCondition("InvoiceForPayment.Date", DataCompositionComparisonType.LessOrEqual, RulesSelection.Name + "End"));
					Query.SetParameter(RulesSelection.Name + "End",  RuleSettings.Value.EndDate);
				EndIf;
			EndIf;
			
		ElsIf Left(RulesSelection.Name, 19) = "SalesProductsAndServices" Then
			
			NewSource = SmallBusinessServer.FindQuerySchemaSource(Operator.Sources, "SalesProductsAndServices");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "SalesProductsAndServices");
				NewSource.Source.Query.SetQueryText("
					|SELECT ALLOWED
					|	CASE
					|		WHEN Sales.Document REFS Document.AcceptanceCertificate
					|			THEN CAST(Sales.Document AS Document.AcceptanceCertificate).Counterparty
					|		WHEN Sales.Document REFS Document.CustomerOrder
					|			THEN CAST(Sales.Document AS Document.CustomerOrder).Counterparty
					|		WHEN Sales.Document REFS Document.AgentReport
					|			THEN CAST(Sales.Document AS Document.AgentReport).Counterparty
					|		WHEN Sales.Document REFS Document.ReportToPrincipal
					|			THEN CAST(Sales.Document AS Document.ReportToPrincipal).Counterparty
					|		WHEN Sales.Document REFS Document.ProcessingReport
					|			THEN CAST(Sales.Document AS Document.ProcessingReport).Counterparty
					|		WHEN Sales.Document REFS Document.SupplierInvoice
					|			THEN CAST(Sales.Document AS Document.SupplierInvoice).Counterparty
					|		WHEN Sales.Document REFS Document.CustomerInvoice
					|			THEN CAST(Sales.Document AS Document.CustomerInvoice).Counterparty
					|		ELSE VALUE(Catalog.Counterparties.EmptyRef)
					|	END AS Counterparty,
					|	Sales.ProductsAndServices AS ProductsAndServices,
					|	Sales.ProductsAndServices.ProductsAndServicesCategory AS ProductsAndServicesCategory
					|FROM
					|	AccumulationRegister.Sales AS Sales");
					
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("SalesProductsAndServices", "Counterparties.Ref = SalesRroductsAndServices.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.Inner;
				
			EndIf;
			
			FilterQuery.Add("NOT SalesProductsAndServices.Counterparty IS NULL");
			InsertedQueryFilter = NewSource.Source.Query.Operators[0].Filter;
			
			If RulesSelection.Name = "SalesProductsAndServicesProductsAndServices" Then
				InsertedQueryFilter.Add(ComparisonCondition("Sales.ProductsAndServices", RuleSettings.ComparisonType, RulesSelection.Name));
				Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			ElsIf RulesSelection.Name = "SalesProductsAndServicesProductsAndServicesGroup" Then
				InsertedQueryFilter.Add(ComparisonCondition("Sales.ProductsAndServices.Parent", RuleSettings.ComparisonType, RulesSelection.Name));
				Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			ElsIf RulesSelection.Name = "SalesProductsAndServicesProductsAndServicesCategory" Then
				InsertedQueryFilter.Add(ComparisonCondition("Sales.ProductsAndServices.ProductsAndServicesCategory", RuleSettings.ComparisonType, RulesSelection.Name));
				Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			ElsIf RulesSelection.Name = "SalesProductsAndServicesPeriod" Then
				If ValueIsFilled(RuleSettings.Value.StartDate) Then
					InsertedQueryFilter.Add(ComparisonCondition("Sales.Period", DataCompositionComparisonType.GreaterOrEqual, RulesSelection.Name + "Begin"));
					Query.SetParameter(RulesSelection.Name + "Begin", RuleSettings.Value.StartDate);
				EndIf;
				If ValueIsFilled(RuleSettings.Value.EndDate) Then
					InsertedQueryFilter.Add(ComparisonCondition("Sales.Period", DataCompositionComparisonType.LessOrEqual, RulesSelection.Name + "End"));
					Query.SetParameter(RulesSelection.Name + "End",  RuleSettings.Value.EndDate);
				EndIf;
			EndIf;
			
		ElsIf Left(RulesSelection.Name, 14) = "SalesIncome" Then
			
			NewSource = SmallBusinessServer.FindQuerySchemaSource(Operator.Sources, "SalesIncome");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "SalesIncome");
				NewSource.Source.Query.SetQueryText("
					|SELECT ALLOWED
					|	CASE
					|		WHEN SalesTurnovers.Document REFS Document.AcceptanceCertificate
					|			THEN CAST(SalesTurnovers.Document AS Document.AcceptanceCertificate).Counterparty
					|		WHEN SalesTurnovers.Document REFS Document.CustomerOrder
					|			THEN CAST(SalesTurnovers.Document AS Document.CustomerOrder).Counterparty
					|		WHEN SalesTurnovers.Document REFS Document.AgentReport
					|			THEN CAST(SalesTurnovers.Document AS Document.AgentReport).Counterparty
					|		WHEN SalesTurnovers.Document REFS Document.ReportToPrincipal
					|			THEN CAST(SalesTurnovers.Document AS Document.ReportToPrincipal).Counterparty
					|		WHEN SalesTurnovers.Document REFS Document.ProcessingReport
					|			THEN CAST(SalesTurnovers.Document AS Document.ProcessingReport).Counterparty
					|		WHEN SalesTurnovers.Document REFS Document.SupplierInvoice
					|			THEN CAST(SalesTurnovers.Document AS Document.SupplierInvoice).Counterparty
					|		WHEN SalesTurnovers.Document REFS Document.CustomerInvoice
					|			THEN CAST(SalesTurnovers.Document AS Document.CustomerInvoice).Counterparty
					|		ELSE VALUE(Catalog.Counterparties.EmptyRef)
					|	END AS Counterparty,
					|	SUM(SalesTurnovers.AmountTurnover) AS Income,
					|	SUM(SalesTurnovers.AmountTurnover - SalesTurnovers.CostTurnover) AS GrossProfit
					|FROM
					|	AccumulationRegister.Sales.Turnovers(, , , ) AS SalesTurnovers
					|
					|GROUP BY
					|	CASE
					|		WHEN SalesTurnovers.Document REFS Document.AcceptanceCertificate
					|			THEN CAST(SalesTurnovers.Document AS Document.AcceptanceCertificate).Counterparty
					|		WHEN SalesTurnovers.Document REFS Document.CustomerOrder
					|			THEN CAST(SalesTurnovers.Document AS Document.CustomerOrder).Counterparty
					|		WHEN SalesTurnovers.Document REFS Document.AgentReport
					|			THEN CAST(SalesTurnovers.Document AS Document.AgentReport).Counterparty
					|		WHEN SalesTurnovers.Document REFS Document.ReportToPrincipal
					|			THEN CAST(SalesTurnovers.Document AS Document.ReportToPrincipal).Counterparty
					|		WHEN SalesTurnovers.Document REFS Document.ProcessingReport
					|			THEN CAST(SalesTurnovers.Document AS Document.ProcessingReport).Counterparty
					|		WHEN SalesTurnovers.Document REFS Document.SupplierInvoice
					|			THEN CAST(SalesTurnovers.Document AS Document.SupplierInvoice).Counterparty
					|		WHEN SalesTurnovers.Document REFS Document.CustomerInvoice
					|			THEN CAST(SalesTurnovers.Document AS Document.CustomerInvoice).Counterparty
					|		ELSE VALUE(Catalog.Counterparties.EmptyRef)
					|	END");
				
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("SalesIncome", "Counterparties.Ref = SalesIncome.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.LeftOuter;
				
			EndIf;
			
			SalesVirtualTableParameters = NewSource.Source.Query.Operators[0].Sources[0].Source.Parameters;
			
			If RulesSelection.Name = "SalesIncomeIncome" Then
				FilterQuery.Add(ComparisonCondition("ISNULL(SalesIncome.Income, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			ElsIf RulesSelection.Name = "SalesIncomeGrossProfit" Then
				FilterQuery.Add(ComparisonCondition("ISNULL(SalesIncome.GrossProfit, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			ElsIf RulesSelection.Name = "SalesIncomePeriod" Then
				If ValueIsFilled(RuleSettings.Value.StartDate) Then
					SalesVirtualTableParameters[0].Expression = New QuerySchemaExpression("&" + RulesSelection.Name + "Begin");
					Query.SetParameter(RulesSelection.Name + "Begin", RuleSettings.Value.StartDate);
				EndIf;
				If ValueIsFilled(RuleSettings.Value.EndDate) Then
					SalesVirtualTableParameters[1].Expression = New QuerySchemaExpression("&" + RulesSelection.Name + "End");
					Query.SetParameter(RulesSelection.Name + "End",  RuleSettings.Value.EndDate);
				EndIf;
			EndIf;
			
		ElsIf RulesSelection.Name = "CustomerDebtAmount" Then
			
			NewSource = SmallBusinessServer.FindQuerySchemaSource(Operator.Sources, "CustomerDebt");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "CustomerDebtAmount");
				NewSource.Source.Query.SetQueryText("
					|SELECT ALLOWED
					|	AccountsReceivableBalances.Counterparty,
					|	AccountsReceivableBalances.AmountBalance AS DebtAmount
					|FROM
					|	AccumulationRegister.AccountsReceivable.Balance(, SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
					|WHERE
					|	AccountsReceivableBalances.AmountBalance > 0");
				
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("CustomerDebtAmount", "Counterparties.Ref = CustomerDebtAmount.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.LeftOuter;
				
			EndIf;
			
			FilterQuery.Add(ComparisonCondition("ISNULL(CustomerDebtAmount.DebtAmount, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
			Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			
		ElsIf RulesSelection.Name = "CustomerDebtTerm" Then
			
			NewSource = SmallBusinessServer.FindQuerySchemaSource(Operator.Sources, "CustomerDebtTerm");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "CustomerDebtTerm");
				NewSource.Source.Query.SetQueryText("
					|SELECT ALLOWED
					|	NestedSelect.Counterparty AS Counterparty,
					|	MAX(CASE
					|			WHEN NestedSelect.TermPaymentFromCustomer > 0
					|					AND DATEDIFF(NestedSelect.DateAccountingDocument, &CurrentDate, Day) > NestedSelect.TermPaymentFromCustomer
					|				THEN DATEDIFF(NestedSelect.DateAccountingDocument, &CurrentDate, Day) - NestedSelect.TermPaymentFromCustomer
					|			ELSE 0
					|		END) AS DelayTerm
					|FROM
					|	(SELECT
					|		AccountsReceivableBalances.Counterparty AS Counterparty,
					|		CASE
					|			WHEN AccountsReceivableBalances.Contract.CustomerPaymentDueDate > 0
					|				THEN AccountsReceivableBalances.Contract.CustomerPaymentDueDate
					|			WHEN CustomerPaymentDueDate.Value > 0
					|				THEN CustomerPaymentDueDate.Value
					|			ELSE 0
					|		END AS TermPaymentFromCustomer,
					|		AccountsReceivableBalances.Document.Date AS DateAccountingDocument
					|	IN
					|		AccumulationRegister.AccountsReceivable.Balance AS AccountsReceivableBalances,
					|		Constant.CustomerPaymentDueDate AS CustomerPaymentDueDate
					|	WHERE
					|		AccountsReceivableBalances.Document <> UNDEFINED
					|		AND AccountsReceivableBalances.AmountBalance > 0
					|		AND AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
					|		AND DATEDIFF(AccountsReceivableBalances.Document.Date, &CurrentDate, Day) >= 0) AS NestedSelect
					|
					|GROUP BY
					|	NestedSelect.Counterparty");
					
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("CustomerDebtTerm", "Counterparties.Ref = CustomerDebtTerm.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.LeftOuter;
				
			EndIf;
			
			FilterQuery.Add(ComparisonCondition("ISNULL(CustomerDebtTerm.DelayTerm, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
			Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			Query.SetParameter("CurrentDate", CurrentDate());
			
		ElsIf Left(RulesSelection.Name, 23) = "VendorDebtAmount" Then
			
			NewSource = SmallBusinessServer.FindQuerySchemaSource(Operator.Sources, "VendorDebtAmount");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "VendorDebtAmount");
				NewSource.Source.Query.SetQueryText("
					|SELECT ALLOWED
					|	AccountsPayableBalances.Counterparty,
					|	AccountsPayableBalances.AmountBalance AS DebtAmount
					|FROM
					|	AccumulationRegister.AccountsPayable.Balance(, SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances");
				
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("VendorDebtAmount", "Counterparties.Ref = DebtToVendorAmount.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.LeftOuter;
				
			EndIf;
			
			FilterQuery.Add(ComparisonCondition("ISNULL(DebtToVendorAmount.DebtAmount, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
			Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			
		ElsIf RulesSelection.Name = "VendorDebtTerm" Then
			
			NewSource = SmallBusinessServer.FindQuerySchemaSource(Operator.Sources, "VendorDebtTerm");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "VendorDebtTerm");
				NewSource.Source.Query.SetQueryText("
					|SELECT ALLOWED
					|	NestedSelect.Counterparty AS Counterparty,
					|	MAX(CASE
					|			WHEN NestedSelect.VendorPaymentDueDate > 0
					|					AND DATEDIFF(NestedSelect.DateAccountingDocument, &CurrentDate, Day) > NestedSelect.VendorPaymentDueDate
					|				THEN DATEDIFF(NestedSelect.DateAccountingDocument, &CurrentDate, Day) - NestedSelect.VendorPaymentDueDate
					|			ELSE 0
					|		END) AS DelayTerm
					|FROM
					|	(SELECT
					|		AccountsPayableBalances.Counterparty AS Counterparty,
					|		CASE
					|			WHEN AccountsPayableBalances.Contract.VendorPaymentDueDate > 0
					|				THEN AccountsPayableBalances.Contract.VendorPaymentDueDate
					|			WHEN VendorPaymentDueDate.Value > 0
					|				THEN VendorPaymentDueDate.Value
					|			ELSE 0
					|		END AS VendorPaymentDueDate,
					|		AccountsPayableBalances.Document.Date AS DateAccountingDocument
					|	IN
					|		AccumulationRegister.AccountsPayable.Balance(, ) AS AccountsPayableBalances,
					|		Constant.VendorPaymentDueDate AS VendorPaymentDueDate
					|	WHERE
					|		AccountsPayableBalances.Document <> UNDEFINED
					|		AND AccountsPayableBalances.AmountBalance > 0
					|		AND AccountsPayableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
					|		AND DATEDIFF(AccountsPayableBalances.Document.Date, &CurrentDate, Day) >= 0) AS NestedSelect
					|
					|GROUP BY
					|	NestedSelect.Counterparty");
				
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("VendorDebtTerm", "Counterparties.Ref = SupplierDebtTerm.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.LeftOuter;
				
			EndIf;
			
			FilterQuery.Add(ComparisonCondition("ISNULL(SupplierDebtTerm.DelayTerm, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
			Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			Query.SetParameter("CurrentDate", CurrentDate());
			
		EndIf;
		
	EndDo;
	
	Query.Text = QuerySchema.GetQueryText();
	
	Return Query;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure adds comparison kinds to the rule
//
// Parameters:
//  Rule					 - ValueTableRow - the
//  AddedComparisonTypes filled in rule - String - comparison kinds in
//  row, separator , DefaultKindNumber	 - Number - number of rule comparison that is also a default value
Procedure AddComparisonTypes(Rule, AddedComparisonsKinds, DefaultTypeNumber = 1)
	
	TypesArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(AddedComparisonsKinds, ",");
	
	For Each KindInString IN TypesArray Do
		If KindInString = "Equal" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.Equal,			 NStr("en='Equal';ru='равных'"));
		ElsIf KindInString = "NotEqual" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.NotEqual,		 NStr("en='Not equal';ru='Не равно'"));
		ElsIf KindInString = "Greater" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.Greater,		 NStr("en='Greater';ru='большая'"));
		ElsIf KindInString = "GreaterOrEqual" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.GreaterOrEqual, NStr("en='More or equal';ru='Больше или равно'"));
		ElsIf KindInString = "Less" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.Less,		 NStr("en='Less';ru='Меньше'"));
		ElsIf KindInString = "LessOrEqual" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.LessOrEqual, NStr("en='Less or equal';ru='Меньше или равно'"));
		ElsIf KindInString = "InList" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.InList,		 NStr("en='In the list';ru='В списке'"));
		ElsIf KindInString = "NotInList" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.NotInList,		 NStr("en='Not in the list';ru='Не в списке'"));
		ElsIf KindInString = "InHierarchy" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.InHierarchy,		 NStr("en='In group';ru='В группе'"));
		ElsIf KindInString = "NotInHierarchy" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.NotInHierarchy,	 NStr("en='Not in group';ru='Не в группе'"));
		ElsIf KindInString = "Filled" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.Filled,		 NStr("en='filled in';ru='заполненный'"));
		ElsIf KindInString = "NotFilled" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.NotFilled,	 NStr("en='Not filled in';ru='Не заполнено'"));
		ElsIf KindInString = "BeginsWith" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.BeginsWith,	 NStr("en='Begins with';ru='Начинается с'"));
		ElsIf KindInString = "NotBeginsWith" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.NotBeginsWith,	 NStr("en='Does not begin with';ru='Не начинается с'"));
		ElsIf KindInString = "Contains" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.Contains,		 NStr("en='Contains';ru='Содержит'"));
		ElsIf KindInString = "NotContains" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.NotContains,	 NStr("en='Does not contain';ru='Не содержит'"));
		EndIf;
	EndDo;
	
	Rule.ComparisonType = Rule.AvailableComparisonTypes[DefaultTypeNumber-1].Value;
	
EndProcedure

// Function generates the template for the Details logical query operator
//
// Parameters:
//  ComparisonTypeRules	 - DataCompositionComparisonType	 - makes sense for
//  the TemplateRow row values		 - String	 - the
// Return value source value:
//  String - template for using in the query
Function OperatorTemplateDetails(ComparisonTypeRules, val RowTemplate)
	
	// Substitute service characters from the source row
	CharsToReplace = "%_[]";
	For CharacterNumber = 1 To StrLen(RowTemplate) Do
		Char = Mid(CharsToReplace, CharacterNumber, 1);
		RowTemplate = StrReplace(RowTemplate, Mid(CharsToReplace, CharacterNumber, 1), "§" + Char);
	EndDo;
	
	If ComparisonTypeRules = DataCompositionComparisonType.BeginsWith Then
		RowTemplate = RowTemplate + "%";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotBeginsWith Then
		RowTemplate = RowTemplate + "%";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.Contains Then
		RowTemplate = "%" + RowTemplate + "%";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotContains Then
		RowTemplate = "%" + RowTemplate + "%";
	EndIf;
	
	Return RowTemplate;
	
EndFunction

// Function generates a condition for placing to query filter
//
// Parameters:
//  Field				 - String	 - query field on which
//  the RuleComparisonType condition is imposed	 - DataCompositionComparisonType	 - the
//  ParameterName comparison kind		 - String	 - name of
// the Return value set parameter:
//  String - query selection condition
Function ComparisonCondition(Field, ComparisonTypeRules, ParameterName)
	
	If ComparisonTypeRules = DataCompositionComparisonType.Equal Then
		ComparisonCondition = Field + " = " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotEqual Then
		ComparisonCondition = Field + " <> " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.Greater Then
		ComparisonCondition = Field + " > " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.GreaterOrEqual Then
		ComparisonCondition = Field + " >= " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.Less Then
		ComparisonCondition = Field + " < " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.LessOrEqual Then
		ComparisonCondition = Field + " <= " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.InList Then
		ComparisonCondition = Field + " IN " + "(&" + ParameterName + ")";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotInList Then
		ComparisonCondition = "Not " + Field + " IN " + "(&" + ParameterName + ")";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.InHierarchy Then
		ComparisonCondition = Field + " IN HIERARCHY " + "(&" + ParameterName + ")";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotInHierarchy Then
		ComparisonCondition = "Not " + Field + " IN HIERARCHY " + "(&" + ParameterName + ")";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.Filled Then
		ComparisonCondition = Field + " <> " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotFilled Then
		ComparisonCondition = Field + " = " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.BeginsWith Then
		ComparisonCondition = Field + " LIKE " + "&" + ParameterName + " ESCAPE ""§""";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotBeginsWith Then
		ComparisonCondition = "Not " + Field + " LIKE " + "&" + ParameterName + " ESCAPE ""§""";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.Contains Then
		ComparisonCondition = Field + " LIKE " + "&" + ParameterName + " ESCAPE ""§""";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotContains Then
		ComparisonCondition = "Not " + Field + " LIKE " + "&" + ParameterName + " ESCAPE ""§""";
	EndIf;
	
	Return ComparisonCondition;
	
EndFunction

#EndRegion

#EndIf