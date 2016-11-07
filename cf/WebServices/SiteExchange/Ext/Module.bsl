
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

Function GetStructureParametersOfExchange()

	MainParameters = ExchangeWithSite.GetMainExchangeParametersStructure();
	
	MainParameters.Insert("ExchangeOverWebService", True);
	MainParameters.Insert("PriceKindsArray", New Array);
	MainParameters.Insert("ExportBalanceForWarehouses", False);
	
	// For compatibility with common module functions ExchangeWithSite
	MainParameters.Insert("ExportPictures", False);
	
	DirectoriesTableStructure = New Structure;
	
	GroupList = New ValueList;
	DirectoriesTableStructure.Insert("GroupList", GroupList);
	
	ResultStructure = New Structure("ProductsExported,ExportedPictures,ExportedOffers,ErrorDescription", 0, 0, 0, "");
	DirectoriesTableStructure.Insert("ResultStructure", ResultStructure);
	
	MainParameters.Insert("DirectoriesTableRow", DirectoriesTableStructure);
	
	URI = "urn:1C.ru:commerceml_205";
	CMLPackage = XDTOFactory.packages.Get(URI);
	
	BusinessInformationType = CMLPackage.Get("BusinessInformation");
	BusinessInformationXTDO = XDTOFactory.Create(BusinessInformationType);
	
	BusinessInformationXTDO.SchemaVersion = "2.05";
	BusinessInformationXTDO.GeneratingDate = MainParameters.GeneratingDate;
	
	MainParameters.Insert("EmptyPackageXDTO", BusinessInformationXTDO);
	
	Return MainParameters;
	
EndFunction // GetExchangeParameterStructure()

Function GetRefByIdentifier(ObjectManager, Val GUIDString)
	
	NewGUID = New UUID(GUIDString);
	
	Try
		ObjectReference = ObjectManager.GetRef(NewGUID);
	Except
		ErrorDescription = ErrorInfo();
		WriteLogEvent(NSTr("en='GetPictureProc: failed to receive object by ID.';ru='GetPicture: не удалось получить объект по идентификатору.'"), EventLogLevel.Error,,, ErrorDescription.Definition);
		Raise;
	EndTry;
	
	Return ObjectReference;
	
EndFunction

// Receives files attached to products.
//
// Parameters:
//  ArrayOfProductsRef - array containing references to products.
//  PermittedPictureTypes - array containing the allowed picture types.
//
// Returns:
//  Selection of files.
//
Function GetAttachedFiles(ArrayOfProductsRef, PermittedPictureTypes)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProductsAndServices.PictureFile AS PictureFile
	|INTO TemporaryTableMainImages
	|FROM
	|	Catalog.ProductsAndServices AS ProductsAndServices
	|WHERE
	|	ProductsAndServices.Ref IN(&ArrayOfProductsRef)
	|
	|INDEX BY
	|	PictureFile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Files.FileOwner AS ProductsAndServices,
	|	Files.Ref AS File,
	|	Files.Description AS Description,
	|	Files.Definition AS Definition,
	|	Files.CurrentVersionVolume AS Volume,
	|	Files.CurrentVersionExtension AS Extension,
	|	Files.CurrentVersionPathToFile AS PathToFile,
	|	Files.CurrentVersion AS CurrentVersion
	|INTO TemporaryTableFiles
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.FileOwner IN(&ArrayOfProductsRef)
	|	AND Files.CurrentVersionExtension IN(&PermittedPictureTypes)
	|	AND Files.Ref = CAST(Files.FileOwner AS Catalog.ProductsAndServices).Ref.PictureFile
	|	AND Files.Ref In
	|			(SELECT
	|				TemporaryTableMainImages.PictureFile
	|			FROM
	|				TemporaryTableMainImages AS TemporaryTableMainImages)
	|
	|INDEX BY
	|	CurrentVersion
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableFiles.ProductsAndServices AS ProductsAndServices,
	|	TemporaryTableFiles.File AS File,
	|	TemporaryTableFiles.Description AS Description,
	|	TemporaryTableFiles.Definition AS Definition,
	|	TemporaryTableFiles.Volume AS Volume,
	|	TemporaryTableFiles.Extension AS Extension,
	|	TemporaryTableFiles.PathToFile AS PathToFile,
	|	VersionStoredFiles.FileVersion.FileStorageType AS FileStorageType,
	|	VersionStoredFiles.StoredFile AS StoredFile
	|FROM
	|	TemporaryTableFiles AS TemporaryTableFiles
	|		LEFT JOIN InformationRegister.VersionStoredFiles AS VersionStoredFiles
	|		ON TemporaryTableFiles.CurrentVersion = VersionStoredFiles.FileVersion
	|			AND (VersionStoredFiles.FileVersion.FileStorageType = VALUE(Enum.FileStorageTypes.InInfobase))
	|
	|ORDER BY
	|	ProductsAndServices";
	
	Query.SetParameter("PermittedPictureTypes", PermittedPictureTypes);
	Query.SetParameter("ArrayOfProductsRef", ArrayOfProductsRef);
	
	Return Query.Execute().Select();
	
EndFunction

// Generate batch query to get data required to export classifier and directory.
//
Procedure AddQueriesToBatchQueryToExportProductsAndServices(QueryText, Parameters)
	
	QueryText = QueryText + Chars.LF + ";" + Chars.LF
		+ "SELECT DISTINCT
		|	TemporaryTableProductsAndServices.ProductsAndServices AS ProductsAndServices,
		|	TemporaryTableProductsAndServices.DeletionMark AS DeletionMark,
		|	TemporaryTableProductsAndServices.Parent AS Parent,
		|	TemporaryTableProductsAndServices.Code AS Code,
		|	TemporaryTableProductsAndServices.Description AS Description,
		|	SubString(TemporaryTableProductsAndServices.ProductsAndServices.DescriptionFull, 1, 100) AS DescriptionFull,
		|	SubString(TemporaryTableProductsAndServices.ProductsAndServices.Comment, 1, 200) AS Comment,
		|	TemporaryTableProductsAndServices.SKU AS SKU,
		|	TemporaryTableProductsAndServices.ProductsAndServicesKind AS ProductsAndServicesKind,
		|	TemporaryTableProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType,
		|	TemporaryTableProductsAndServices.MeasurementUnit AS MeasurementUnit,
		|	TemporaryTableProductsAndServices.MeasurementUnitCode AS MeasurementUnitCode,
		|	TemporaryTableProductsAndServices.MeasurementUnitDescriptionFull AS MeasurementUnitDescriptionFull,
		|	TemporaryTableProductsAndServices.MeasurementUnitInternationalAbbreviation AS MeasurementUnitInternationalAbbreviation,
		|	TemporaryTableProductsAndServices.VATRate AS VATRate,
		|	TemporaryTableProductsAndServices.PictureFile AS PictureFile,
		|	ISNULL(TemporaryTableBarcodesForDirectory.Barcode, """") AS Barcode
		|FROM
		|	TemporaryTableProductsAndServices AS TemporaryTableProductsAndServices
		|		LEFT JOIN TemporaryTableBarcodesForDirectory AS TemporaryTableBarcodesForDirectory
		|		ON TemporaryTableProductsAndServices.ProductsAndServices = TemporaryTableBarcodesForDirectory.ProductsAndServices
		|
		|ORDER BY
		|	ProductsAndServices
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBarcodesForDirectory
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TemporaryTableProductsAndServices.ProductsAndServices AS ProductsAndServices,
		|	TemporaryTableProductsAndServices.Characteristic AS Characteristic,
		|	ProductsAndServicesCharacteristicsAdditionalAttributes.Property AS Property,
		|	ProductsAndServicesCharacteristicsAdditionalAttributes.Property.Description AS Description,
		|	ProductsAndServicesCharacteristicsAdditionalAttributes.Value AS Value
		|FROM
		|	TemporaryTableProductsAndServices AS TemporaryTableProductsAndServices
		|		LEFT JOIN Catalog.ProductsAndServicesCharacteristics.AdditionalAttributes AS ProductsAndServicesCharacteristicsAdditionalAttributes
		|		ON TemporaryTableProductsAndServices.Characteristic = ProductsAndServicesCharacteristicsAdditionalAttributes.Ref
		|WHERE
		|	Not TemporaryTableProductsAndServices.Characteristic = VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
		|TOTALS BY
		|	ProductsAndServices, Characteristic
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	AdditionalAttributes.ProductsAndServices AS ProductsAndServices,
		|	AdditionalAttributes.Property AS Property,
		|	ValuesOfAdditionalAttributes.Value AS Value
		|INTO TemporaryTableProductsAndServicesProperties
		|FROM
		|	(SELECT
		|		TemporaryTableProductsAndServices.ProductsAndServices AS ProductsAndServices,
		|		SetsAdditionalDetailsAndAdditionalInformationAttributes.Property AS Property
		|	FROM
		|		TemporaryTableProductsAndServices AS TemporaryTableProductsAndServices
		|			INNER JOIN Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes AS SetsAdditionalDetailsAndAdditionalInformationAttributes
		|			ON (SetsAdditionalDetailsAndAdditionalInformationAttributes.Ref = VALUE(Catalog.AdditionalAttributesAndInformationSets.Catalog_ProductsAndServices))) AS AdditionalAttributes
		|		LEFT JOIN Catalog.ProductsAndServices.AdditionalAttributes AS ValuesOfAdditionalAttributes
		|		ON AdditionalAttributes.ProductsAndServices = ValuesOfAdditionalAttributes.Ref
		|			AND AdditionalAttributes.Property = ValuesOfAdditionalAttributes.Property
		|	
		|UNION
		|	
		|SELECT
		|	AdditionalInformation.ProductsAndServices,
		|	AdditionalInformation.Property,
		|	ValuesOfAdditionalInformation.Value
		|FROM
		|	(SELECT
		|		TemporaryTableProductsAndServices.ProductsAndServices AS ProductsAndServices,
		|		SetsAdditionalDetailsAndAdditionalInformationAdditionalInformation.Property AS Property
		|	FROM
		|		TemporaryTableProductsAndServices AS TemporaryTableProductsAndServices
		|			INNER JOIN Catalog.AdditionalAttributesAndInformationSets.AdditionalInformation AS SetsAdditionalDetailsAndAdditionalInformationAdditionalInformation
		|			ON (SetsAdditionalDetailsAndAdditionalInformationAdditionalInformation.Ref = VALUE(Catalog.AdditionalAttributesAndInformationSets.Catalog_ProductsAndServices))) AS AdditionalInformation
		|		LEFT JOIN InformationRegister.AdditionalInformation AS ValuesOfAdditionalInformation
		|		ON AdditionalInformation.ProductsAndServices = ValuesOfAdditionalInformation.Object
		|			AND AdditionalInformation.Property = ValuesOfAdditionalInformation.Property
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ProductsAndServicesPropertiesTable.Property AS Property,
		|	ProductsAndServicesPropertiesTable.Property.ValueType AS ValueType,
		|	ProductsAndServicesPropertiesTable.Value AS Value
		|FROM
		|	(SELECT DISTINCT
		|		TemporaryTableProductsAndServicesProperties.Property AS Property,
		|		TemporaryTableProductsAndServicesProperties.Value AS Value
		|	FROM
		|		TemporaryTableProductsAndServicesProperties AS TemporaryTableProductsAndServicesProperties) AS ProductsAndServicesPropertiesTable
		|TOTALS BY
		|	Property
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TemporaryTableProductsAndServicesProperties.ProductsAndServices AS ProductsAndServices,
		|	TemporaryTableProductsAndServicesProperties.Property AS Property,
		|	TemporaryTableProductsAndServicesProperties.Value AS Value
		|FROM
		|	TemporaryTableProductsAndServicesProperties AS TemporaryTableProductsAndServicesProperties
		|
		|ORDER BY
		|	ProductsAndServices
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableProductsAndServicesProperties
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	Companies.Ref AS Counterparty,
		|	Companies.Description AS Description,
		|	Companies.DescriptionFull AS DescriptionFull,
		|	Companies.LegalEntityIndividual AS LegalEntityIndividual,
		|	Companies.TIN AS TIN,
		|	Companies.KPP AS KPP,
		|	Companies.CodeByOKPO AS CodeByOKPO,
		|	Companies.ContactInformation.(
		|		Type AS Type,
		|		Kind AS Kind,
		|		Presentation AS Presentation,
		|		FieldsValues AS FieldsValues
		|	) AS ContactInformation
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.Ref = &CompanyFolderOwner
		|;
		|
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TemporaryTableProductsAndServices.ProductsAndServices AS ProductsAndServices
		|FROM
		|	TemporaryTableProductsAndServices AS TemporaryTableProductsAndServices
		|TOTALS BY
		|	ProductsAndServices ONLY HIERARCHY
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableProductsAndServices";
	
EndProcedure

Procedure SetComposerFilters(	SettingsComposer, 
										ChangeDate = Undefined, 
										GroupCode = Undefined, 
										CodeWarehouse = Undefined, 
										CodeCompany = Undefined) Export
	
	Filter = SettingsComposer.Settings.Filter;
	
	If TypeOf(ChangeDate) = Type("Date") AND ValueIsFilled(ChangeDate) Then
		
		NewItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
		NewItem.UserSettingID = "SoftwareSelectionByDateModified";
		NewItem.LeftValue 	= New DataCompositionField("ProductsAndServices.ChangeDate");
		NewItem.ComparisonType 	= DataCompositionComparisonType.GreaterOrEqual;
		NewItem.RightValue = ChangeDate;
		NewItem.Use 	= True;
		
	EndIf;
	
	If ValueIsFilled(GroupCode) Then
		
		ProductsAndServicesGroup = Catalogs.ProductsAndServices.FindByCode(GroupCode);
		
		If ValueIsFilled(ProductsAndServicesGroup) Then
			NewItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
			NewItem.UserSettingID = "ProgramFilterByGroup";
			NewItem.LeftValue 	= New DataCompositionField("ProductsAndServices");
			NewItem.ComparisonType 	= DataCompositionComparisonType.InHierarchy;
			NewItem.RightValue = ProductsAndServicesGroup;
			NewItem.Use 	= True;
		EndIf;
		
	EndIf;

	If ValueIsFilled(CodeWarehouse) Then
		
		Warehouse = Catalogs.StructuralUnits.FindByCode(CodeWarehouse);
		If Warehouse = Undefined Then
			Warehouse = Catalogs.StructuralUnits.EmptyRef();
		EndIf;
		
		NewItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
		NewItem.UserSettingID = "ProgramFilterByWarehouse";
		NewItem.LeftValue 	= New DataCompositionField("WarehouseForBalances");
		NewItem.ComparisonType 	= DataCompositionComparisonType.Equal;
		NewItem.RightValue = Warehouse;
		NewItem.Use 	= True;
		
		NewItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
		NewItem.UserSettingID = "ProgramFilterByBalance";
		NewItem.LeftValue 	= New DataCompositionField("Balance");
		NewItem.ComparisonType 	= DataCompositionComparisonType.Greater;
		NewItem.RightValue = 0;
		NewItem.Use 	= True;
		
	EndIf;
		
	If ValueIsFilled(CodeCompany) Then
		
		Company = Catalogs.Companies.FindByCode(CodeCompany);
		If Company = Undefined Then
			Company = Catalogs.Companies.EmptyRef();
		EndIf;
		
		NewItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
		NewItem.UserSettingID = "ProgramFilterByCompany";
		NewItem.LeftValue 	= New DataCompositionField("Company");
		NewItem.ComparisonType 	= DataCompositionComparisonType.Equal;
		NewItem.RightValue = Company;
		NewItem.Use 	= True;
		
		If Not ValueIsFilled(CodeWarehouse) Then
			NewItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
			NewItem.UserSettingID = "ProgramFilterByBalance";
			NewItem.LeftValue 	= New DataCompositionField("Balance");
			NewItem.ComparisonType 	= DataCompositionComparisonType.Greater;
			NewItem.RightValue = 0;
			NewItem.Use 	= True;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure PrepareDataForExportingProductsAndServices(Parameters)

	ProductsExportScheme = ExchangePlans.ExchangeSmallBusinessSite.GetTemplate("ProductsExportSchemeWebService");
	
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(ProductsExportScheme)); 
	SettingsComposer.LoadSettings(ProductsExportScheme.DefaultSettings);

	DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("UseCharacteristics");
	DCSParameter.Value = Parameters.UseCharacteristics;
	DCSParameter.Use = True;
	
	DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("CompanyFolderOwner");
	DCSParameter.Value = Parameters.CompanyFolderOwner;
	DCSParameter.Use = True;
	
	DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("PermittedPictureTypes");
	DCSParameter.Value = Parameters.PermittedPictureTypes;
	DCSParameter.Use = True;
	
	DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("PermittedProductsAndServicesTypes");
	DCSParameter.Value = Parameters.PermittedProductsAndServicesTypes;
	DCSParameter.Use = True;
	
	//Filter.
	
	SetComposerFilters(SettingsComposer, Parameters.ChangeDate, Parameters.GroupCode);
	
	// Query.
	
	Query = ExchangeWithSite.GetQueryFromCompositionTemplate(SettingsComposer, ProductsExportScheme);
	AddQueriesToBatchQueryToExportProductsAndServices(Query.Text, Parameters);
	
	QueryResultArray = Query.ExecuteBatch();
	
	Parameters.Insert("ProductsAndServicesSelection", QueryResultArray[6].Select());
	
	Parameters.Insert("CharacteristicPropertiesTree", 
		QueryResultArray[8].Unload(QueryResultIteration.ByGroups));
	
	Parameters.Insert("ProductsAndServicesPropertiesSelectionForClassificator", 
		QueryResultArray[10].Select(QueryResultIteration.ByGroups));
	
	ProductsAndServicesPropertiesQueryResult = QueryResultArray[11];
	If ProductsAndServicesPropertiesQueryResult.IsEmpty() Then
		ProductsAndServicesPropertiesSelection = Undefined;
	Else
		ProductsAndServicesPropertiesSelection = ProductsAndServicesPropertiesQueryResult.Select();
		ProductsAndServicesPropertiesSelection.Next();
	EndIf;
		
	Parameters.Insert("ProductsAndServicesPropertiesSelection", ProductsAndServicesPropertiesSelection);
	
	QueryResultOfDirectoryOwnerCompanyData = QueryResultArray[13];
	If QueryResultOfDirectoryOwnerCompanyData.IsEmpty() Then
		DataSelectionOfDirectoryOwnerCompany = Undefined;
	Else
		DataSelectionOfDirectoryOwnerCompany = QueryResultOfDirectoryOwnerCompanyData.Select();
		DataSelectionOfDirectoryOwnerCompany.Next();
	EndIf;
	
	Parameters.Insert("CompanyDataOfDirectoryOwner", DataSelectionOfDirectoryOwnerCompany);
	
	Parameters.Insert("GroupsTree", QueryResultArray[14].Unload(QueryResultIteration.ByGroupsWithHierarchy));
	Parameters.Insert("SelectionFiles", Undefined);
		
EndProcedure // PrepareDataToExportProductsAndServices(Parameters)

Function GetClassifierAndDirectory(ChangeDate, GroupCode)
	
	Parameters = GetStructureParametersOfExchange();
	
	If ValueIsFilled(GroupCode)
		AND Not ValueIsFilled(Catalogs.ProductsAndServices.FindByCode(GroupCode)) Then
		Return Parameters.EmptyPackageXDTO;
	EndIf;
	
	Parameters.Insert("ChangeDate", ChangeDate);
	Parameters.Insert("GroupCode"	  , GroupCode);
	
	PrepareDataForExportingProductsAndServices(Parameters);
	
	If Parameters.ProductsAndServicesSelection.Count() = 0 Then
		Return Parameters.EmptyPackageXDTO;
	EndIf;
	
	IDDirectory = String(New UUID);
	
	URI = "urn:1C.ru:commerceml_205";
	CMLPackage = XDTOFactory.packages.Get(URI);	
	
	BusinessInformationType = CMLPackage.Get("BusinessInformation");
	BusinessInformationXTDO = XDTOFactory.Create(BusinessInformationType);
	
	BusinessInformationXTDO.SchemaVersion = "2.05";
	BusinessInformationXTDO.GeneratingDate = Parameters.GeneratingDate;
	
	ClassifierType = CMLPackage.Get("Classifier");
	ClassifierXDTO = XDTOFactory.Create(ClassifierType);
	
	ClassifierXDTO.ID = IDDirectory;
	ClassifierXDTO.Description = "Classifier";
	
	ClassifierXDTO.Owner = ExchangeWithSite.GetXDTOCounterparty(Parameters.CompanyDataOfDirectoryOwner, CMLPackage);
	
	ExchangeWithSite.AddXDTOClassifierGroups(ClassifierXDTO, Parameters.GroupsTree.Rows, Undefined, CMLPackage);
	ExchangeWithSite.AddProductsAndServicesPropertiesIntoXDTOClassifier(ClassifierXDTO, CMLPackage, Parameters.ProductsAndServicesPropertiesSelectionForClassificator);
	
	Try
		ClassifierXDTO.Validate();
		BusinessInformationXTDO.Classifier = ClassifierXDTO;
	Except
		Return Parameters.EmptyPackageXDTO;
	EndTry;
	
	DirectoryType = CMLPackage.Get("Directory");
	XDTODirectory = XDTOFactory.Create(DirectoryType);
	
	XDTODirectory.ContainsChangesOnly = Parameters.ChangeDate <> '00010101';
	XDTODirectory.ContainsChangesOnly = False;
	XDTODirectory.ID = IDDirectory;
	XDTODirectory.ClassifierIdentifier = IDDirectory;
	XDTODirectory.Description = "Directory";
	
	XDTODirectory.Owner = ExchangeWithSite.GetXDTOCounterparty(Parameters.CompanyDataOfDirectoryOwner, CMLPackage);
	
	ExchangeWithSite.AddProductsAndServicesInXDTODirectory(XDTODirectory, CMLPackage, Parameters);
	
	Try
		XDTODirectory.Validate();
		BusinessInformationXTDO.Directory = XDTODirectory;
	Except
		Return Parameters.EmptyPackageXDTO;
	EndTry;
	
	Return BusinessInformationXTDO;
	
EndFunction

// Generate batch query to get data required to export balances and prices.
//
Procedure AddQueriesToBatchQueryToExportResiduesAndPrices(QueryText, Parameters)
	
	QueryText = QueryText + Chars.LF + ";" + Chars.LF
	  	+ "DROP TemporaryTableProductsAndServicesCharacteristicsBalance
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBarcodesForPrices
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TemporaryTablePriceKinds.PriceKind AS PriceKind,
		|	TemporaryTablePriceKinds.PriceCurrency AS PriceCurrency,
		|	TemporaryTablePriceKinds.PriceIncludesVAT AS PriceIncludesVAT
		|FROM
		|	TemporaryTablePriceKinds AS TemporaryTablePriceKinds
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TemporaryTablePrices.Characteristic AS Characteristic,
		|	ProductsAndServicesCharacteristicsAdditionalAttributes.Property AS Property,
		|	ProductsAndServicesCharacteristicsAdditionalAttributes.Property.Description AS Description,
		|	ProductsAndServicesCharacteristicsAdditionalAttributes.Value AS Value
		|FROM
		|	TemporaryTablePrices AS TemporaryTablePrices
		|		LEFT JOIN Catalog.ProductsAndServicesCharacteristics.AdditionalAttributes AS ProductsAndServicesCharacteristicsAdditionalAttributes
		|		ON TemporaryTablePrices.Characteristic = ProductsAndServicesCharacteristicsAdditionalAttributes.Ref
		|TOTALS BY
		|	Characteristic
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTablePrices
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	Companies.Ref AS Counterparty,
		|	Companies.Description AS Description,
		|	Companies.DescriptionFull AS DescriptionFull,
		|	Companies.LegalEntityIndividual AS LegalEntityIndividual,
		|	Companies.TIN AS TIN,
		|	Companies.KPP AS KPP,
		|	Companies.CodeByOKPO AS CodeByOKPO,
		|	Companies.ContactInformation.(
		|		Type AS Type,
		|		Kind AS Kind,
		|		Presentation AS Presentation,
		|		FieldsValues AS FieldsValues
		|	) AS ContactInformation
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.Ref = &CompanyFolderOwner";
	
	EndProcedure

// Fills array with all price kinds.
//
Procedure FillPriceKindsArrayDefault(PriceKindsArray)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	PriceKinds.Ref AS PriceKind
	|FROM
	|	Catalog.PriceKinds AS PriceKinds";
	
	PriceKindsArray = Query.Execute().Unload().UnloadColumn("PriceKind");
	
EndProcedure // FillPriceKindArrayDefault(PriceKindArray)

Procedure PrepareDataToExportResiduesAndPrices(Parameters)
	
	PriceKindsArray = Parameters.PriceKindsArray;
	If PriceKindsArray.Count() = 0 Then
		FillPriceKindsArrayDefault(PriceKindsArray);
	EndIf;
	
	ProductsExportScheme = ExchangePlans.ExchangeSmallBusinessSite.GetTemplate("ProductsExportScheme");
	
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(ProductsExportScheme)); 
	SettingsComposer.LoadSettings(ProductsExportScheme.DefaultSettings);
	
	DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("UseCharacteristics");
	DCSParameter.Value = Parameters.UseCharacteristics;
	DCSParameter.Use = True;
	
	DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("CompanyFolderOwner");
	DCSParameter.Value = Parameters.CompanyFolderOwner;
	DCSParameter.Use = True;
	
	DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("PriceKinds");
	DCSParameter.Value = PriceKindsArray;
	DCSParameter.Use = True;
	
	DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("CurrencyTransactionsAccounting");
	DCSParameter.Value = Parameters.CurrencyTransactionsAccounting;
	DCSParameter.Use = True;
	
	DCSParameter = SettingsComposer.Settings.DataParameters.Items.Find("PermittedProductsAndServicesTypes");
	DCSParameter.Value = Parameters.PermittedProductsAndServicesTypes;
	DCSParameter.Use = True;
	
	 //Filter.
	 
	SetComposerFilters(SettingsComposer, Parameters.ChangeDate, Parameters.GroupCode, Parameters.CodeWarehouse, Parameters.CodeCompany);
	
	// Query.
	
	Query = ExchangeWithSite.GetQueryFromCompositionTemplate(SettingsComposer, ProductsExportScheme);
	AddQueriesToBatchQueryToExportResiduesAndPrices(Query.Text, Parameters);
	
	QueryResultArray = Query.ExecuteBatch();
	
	Parameters.Insert("SelectionOfPrice", QueryResultArray[10].Select());
	Parameters.Insert("PriceKindsSelection", QueryResultArray[13].Select());
	
	Parameters.Insert("CharacteristicPropertiesTree", 
		QueryResultArray[14].Unload(QueryResultIteration.ByGroups));
	
	QueryResultOfDirectoryOwnerCompanyData = QueryResultArray[16];
	If QueryResultOfDirectoryOwnerCompanyData.IsEmpty() Then
		DataSelectionOfDirectoryOwnerCompany = Undefined;
	Else
		DataSelectionOfDirectoryOwnerCompany = QueryResultOfDirectoryOwnerCompanyData.Select();
		DataSelectionOfDirectoryOwnerCompany.Next();
	EndIf;
	
	Parameters.Insert("CompanyDataOfDirectoryOwner", DataSelectionOfDirectoryOwnerCompany);
	
EndProcedure

Function GetBalanceAndPrices(ChangeDate, GroupCode, CodeWarehouse, CodeCompany)
	
	Parameters = GetStructureParametersOfExchange();
	
	If ValueIsFilled(GroupCode)
		AND Not ValueIsFilled(Catalogs.ProductsAndServices.FindByCode(GroupCode)) Then
		Return Parameters.EmptyPackageXDTO;
	EndIf;
	
	Parameters.Insert("ChangeDate" , ChangeDate);
	Parameters.Insert("GroupCode"	   , GroupCode);
	Parameters.Insert("CodeWarehouse"	   , CodeWarehouse);
	Parameters.Insert("CodeCompany", CodeCompany);
	
	IDDirectory = String(New UUID);
	
	URI = "urn:1C.ru:commerceml_205";
	CMLPackage = XDTOFactory.packages.Get(URI);
	
	BusinessInformationType = CMLPackage.Get("BusinessInformation");
	BusinessInformationXTDO = XDTOFactory.Create(BusinessInformationType);
	
	BusinessInformationXTDO.SchemaVersion = "2.05";
	BusinessInformationXTDO.GeneratingDate = Parameters.GeneratingDate;
	
	PrepareDataToExportResiduesAndPrices(Parameters);
	
	If Parameters.SelectionOfPrice.Count() = 0 Then
		Return Parameters.EmptyPackageXDTO;
	EndIf;
	
	XDTOOffersPackage = XDTOFactory.Create(CMLPackage.Get("OffersPackage"));
	
	XDTOOffersPackage.ContainsChangesOnly = False;
	XDTOOffersPackage.ID = IDDirectory;
	XDTOOffersPackage.Description = "Package of offers";
	XDTOOffersPackage.DirectoryId = IDDirectory;
	XDTOOffersPackage.ClassifierIdentifier = IDDirectory;
	
	ExchangeWithSite.AddPriceKindsIntoXDTOOffersPackage(XDTOOffersPackage, CMLPackage, Parameters);
	
	ExchangeWithSite.AddOffersIntoXDTOOffersPackage(XDTOOffersPackage, CMLPackage, Parameters);
	
	Try
		XDTOOffersPackage.Validate();
		BusinessInformationXTDO.OffersPackage = XDTOOffersPackage;
	Except
		Return Parameters.EmptyPackageXDTO;
	EndTry;
	
	Return BusinessInformationXTDO;
	
EndFunction

// Receives customer orders which were modified.
//
// Parameters:
//  ChangeDate - date-time starting from which order was changed.
//
// Returns:
//  Array of customer orders.
//
Function GetOrdersToExport(ChangeDate)
	
	If ChangeDate = '00010101' Then
		Return New Array;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	CustomerOrdersFromSite.CustomerOrder AS CustomerOrder
	|FROM
	|	InformationRegister.CustomerOrdersFromSite AS CustomerOrdersFromSite
	|WHERE
	|	CustomerOrdersFromSite.CustomerOrder.ChangeDate >= &ChangeDate";
	
	Query.SetParameter("ChangeDate", ChangeDate);
	
	Return Query.Execute().Unload().UnloadColumn("CustomerOrder");
	
EndFunction // GetOrdersToExport()

Function RecieveOrders(ChangeDate)
	
	Parameters = GetStructureParametersOfExchange();
	OrderStatusInProcess = ExchangeWithSiteReUse.GetStatusInProcessOfCustomerOrders();
	Parameters.Insert("OrderStatusInProcess", OrderStatusInProcess);
	
	StatisticsStructure = New Structure;
	
	StatisticsStructure.Insert("ProcessedOnImport", 0);
	StatisticsStructure.Insert("Exported" , New Array);
	StatisticsStructure.Insert("Skipped"    , New Array);
	StatisticsStructure.Insert("Updated"    , New Array);
	StatisticsStructure.Insert("Created"    , New Array);
	StatisticsStructure.Insert("Exported"   , New Array);
	
	ChangesArray = GetOrdersToExport(ChangeDate);
	If ValueIsFilled(ChangeDate) AND ChangesArray.Count() = 0 Then
		Return Parameters.EmptyPackageXDTO;
	Else
		XDTOOrders = ExchangeWithSite.GenerateXDTOOrders(ChangesArray, StatisticsStructure, Parameters);
	EndIf;
	
	If XDTOOrders = Undefined Then
		Return Parameters.EmptyPackageXDTO;
	EndIf;
	
	Return XDTOOrders;
	
EndFunction // RecieveOrders()

Function ExportOrders(OrdersDataXDTO)
	
	Parameters = GetStructureParametersOfExchange();
	
	Parameters.Insert("CounterpartiesIdentificationMethod", Enums.CounterpartiesIdentificationMethods.Description);
	Parameters.Insert("GroupForNewCounterparties", Catalogs.Counterparties.EmptyRef());
	Parameters.Insert("GroupForNewProductsAndServices", Catalogs.ProductsAndServices.EmptyRef());
	Parameters.Insert("ProductsExchange", False);
	Parameters.Insert("ExportChangesOnly", False);
	Parameters.Insert("TableOfConformityOrderStatuses", New  ValueTable);
	Parameters.Insert("OrderStatusInProcess", ExchangeWithSiteReUse.GetStatusInProcessOfCustomerOrders());
	Parameters.Insert("CompanyToSubstituteIntoOrders", Catalogs.Companies.EmptyRef());
	
	StatisticsStructure = New Structure;
	
	StatisticsStructure.Insert("ProcessedOnImport", 0);
	StatisticsStructure.Insert("Exported" , New Array);
	StatisticsStructure.Insert("Skipped"    , New Array);
	StatisticsStructure.Insert("Updated"    , New Array);
	StatisticsStructure.Insert("Created"    , New Array);
	
	HasErrors = False;
	ErrorDescription = "";
	
	If Not ExchangeWithSite.ExportOrders(OrdersDataXDTO, StatisticsStructure, Parameters, ErrorDescription) Then 
		
		ExchangeWithSite.AddErrorDescriptionFull(ErrorDescription, NStr("en='Failed to process documents, exported from server.';ru='Не удалось обработать документы, загруженные с сервера.'"));
		HasErrors = True;
		
	EndIf;
	
	WriteOperationExecutionResultToEventLogMonitor(NStr("en='ExchangeWithSite.OrdersImport';ru='ОбменССайтом.ЗагрузкаЗаказов'"), ErrorDescription, HasErrors);
	
	Return Not HasErrors;
	
EndFunction // ExportOrders()

Function GetFileBinaryData(FileData)
	
	FileBinaryData = Undefined;
	
	SystemInfo = New SystemInfo;
	WindowsPlatform = SystemInfo.PlatformType = PlatformType.Windows_x86
		OR SystemInfo.PlatformType = PlatformType.Windows_x86_64;
	
	FileInStorage = FileData.FileStorageType = Enums.FileStorageTypes.InInfobase;
	If FileInStorage Then
		
		If FileData.StoredFile = NULL Then
			FileBinaryData = Undefined;
		Else
			FileBinaryData = FileData.StoredFile.Get();
		EndIf;
		
		If FileBinaryData = Undefined Then
			
			ErrorDescription = ErrorInfo();
			WriteLogEvent(StringFunctionsClientServer.PlaceParametersIntoString(NSTr("en='GetPictureProc: failed to get file data %1 of products and services %2.';ru='GetPicture: не удалось получить данные файла %1 номенклатуры %2.'"),
				FileData.File,
				FileData.ProductsAndServices),
				EventLogLevel.Error,,,
				ErrorDescription.Definition);
			Raise ErrorDescription;
		EndIf;
		
	Else
		
		FileName = ExchangeWithSite.PreparePathForPlatform(WindowsPlatform,
			ExchangeWithSite.GetVolumePathForPlatform(WindowsPlatform, FileData.Volume) + "\" + FileData.PathToFile);
		
		Try
			
			FileBinaryData = New BinaryData(FileName);
			
		Except
			
			//AddErrorDescriptionFull(ErrorDescription, 
			//ExceptionalErrorDescription(NStr("en='ProductsAndServices file export: ';ru='Выгрузка файла номенклатуры: '")
			//+ Parameters.ProductsAndServicesSelection.ProductsAndServices));
			//
			//Return FileURL;
			Raise ErrorInfo();
			
		EndTry;
	EndIf;
	
	Return FileBinaryData;
	
EndFunction

Function GetPicture(ProductIdentifierString)
	
	Parameters = GetStructureParametersOfExchange();
	
	ObjectManager = Catalogs.ProductsAndServices;
	ObjectReference = GetRefByIdentifier(ObjectManager, ProductIdentifierString);
	
	ArrayOfProductsRef = New Array;
	ArrayOfProductsRef.Add(ObjectReference);
	
	Selection = GetAttachedFiles(ArrayOfProductsRef, Parameters.PermittedPictureTypes);
	If Selection.Next() Then
		
		XDTOSerializer = New XDTOSerializer(XDTOFactory);
		FileBinaryData = GetFileBinaryData(Selection);
		
		Try
			PictureXDTO = XDTOSerializer.WriteXDTO(FileBinaryData);
		Except
			Raise ErrorDescription();
		EndTry;
		
	EndIf;
	
	Return PictureXDTO;
	
EndFunction

Procedure WriteOperationExecutionResultToEventLogMonitor(LogEvent, Definition, Error = False)
	
	If Error Then
		JournalLevel = EventLogLevel.Error;
	Else
		JournalLevel = EventLogLevel.Information;
	EndIf;
	
	WriteLogEvent(LogEvent, JournalLevel,,, Definition);
	
EndProcedure

// OPERATIONS FUNCTIONS

Function GetItems(ModificationDate, GroupCode) Export
	
	Return GetClassifierAndDirectory(ModificationDate, GroupCode);

EndFunction

Function GetAmountAndPrices(ModificationDate, GroupCode, WarehouseCode, CompanyCode) Export
	
	Return GetBalanceAndPrices(ModificationDate, GroupCode, WarehouseCode, CompanyCode);
	
EndFunction

Function GetOrders(ModificationDate) Export
	
	Return RecieveOrders(ModificationDate);
	
EndFunction

Function ImportOrders(OrdersData) Export
	
	Return ExportOrders(OrdersData);
	
EndFunction

Function GetPictureProc(ItemID) Export
	
	Return GetPicture(ItemID);
	
EndFunction





