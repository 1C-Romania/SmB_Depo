#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Creates a values table with commands list in an external processing for import from a file.
//
Procedure SetImportCommands(RegistrationParameters) Export
	
	CommandTable = New ValueTable;
	CommandTable.Columns.Add("Presentation", New TypeDescription("String"));
	CommandTable.Columns.Add("ID", New TypeDescription("String"));
	CommandTable.Columns.Add("TemplateWithTemplate", New TypeDescription("String"));
	CommandTable.Columns.Add("FullMetadataObjectName", New TypeDescription("String"));
	
	RegistrationParameters.Insert("ImportCommands", CommandTable);
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

// Tells all required information about the procedure of the data import from a file.
//
// Return
//  value Structure - contains structure with properties:
//     * Presentation                           - String - Presentation in the import variants list.
//     *TemplateNameWithTemplate						 - String - Name of a template with data structure(optional
//                                           parameter, default value - DataLoadFromFile
//     * TemplateMandatoryColumns                        - Array - Contains a list of mandatory fields for filling.
//     * MapColumnTitle	  		 - String - Presentation of the match
//                                                     column in the table header
//                                                     of data match(optional parameter, default value is formed - Catalog: <catalog synonym>).
//     *ObjectName								 - String - Object Name.
//
Function ImportParametersFromFile(CatalogMetadata = Undefined) Export
	
	TemplateMandatoryColumns = New Array;
	For Each Attribute IN CatalogMetadata.Attributes Do
		If Attribute.FillChecking=FillChecking.ShowError Then 
			TemplateMandatoryColumns.Add(Attribute.Name);
		EndIf;
	EndDo;
		
	DefaultParameters = New Structure;
	DefaultParameters.Insert("Title", CatalogMetadata.Presentation());
	DefaultParameters.Insert("MandatoryColumns", TemplateMandatoryColumns);
	DefaultParameters.Insert("DataTypeColumns", New Map);
	Return DefaultParameters;
EndFunction	

// Tells all required information about the procedure of the data import from file to Tabular section.
Function LoadFromFileToTPParameters(TabularSectionName, AdditionalParameters) Export
	
	DefaultParameters= New Structure;
	DefaultParameters.Insert("MandatoryColumns",New Array);
	DefaultParameters.Insert("TemplateNameWithTemplate","LoadFromFile");
	DefaultParameters.Insert("TabularSectionName", TabularSectionName);
	DefaultParameters.Insert("DataTypeColumns", New Map);
	DefaultParameters.Insert("AdditionalParameters", AdditionalParameters);
	
	Return DefaultParameters;
	
EndFunction

// Tells all required information about the procedure of the data import from file for an external processing.
//
// Parameters: 
//    CommandName - String - Command name (Identifier).
//    RefToDataProcessor - Ref - Reference to data processor.
//    TemplateNameWithTemplate - String - Name of a template with columns template for data import.
// Return
//  value Structure - contains structure with properties:
//     * Presentation                           - String - Presentation in the import variants list.
//     *TemplateNameWithTemplate                      - String - Name of a template
//                                                          with data structure(optional parameter, default value - DataLoadFromFile
//     * TemplateMandatoryColumns               - Array - Contains a list of mandatory fields for filling.
//     * MapColumnTitle            - String - Presentation of the match
//                                                           column in the table header
//                                                           of data match(optional parameter, default value is formed - Catalog:
//                                                           <catalog synonym>).
//     *ObjectName                               - String - Object Name.
//
Function LoadFromFileParametersExternalProcessing(CommandName, RefToDataProcessor, TemplateNameWithTemplate) Export
	TemplateMandatoryColumns = New Array;
	
	If Not ValueIsFilled(TemplateNameWithTemplate) Then 
		TemplateNameWithTemplate = "LoadFromFile";
	EndIf;
	
	ImportParameters = New Structure;
	ImportParameters.Insert("TemplateNameWithTemplate", TemplateNameWithTemplate);
	ImportParameters.Insert("TemplateMandatoryColumns", TemplateMandatoryColumns);
	ImportParameters.Insert("ColumnsDataTypeMatch", New Map);
	
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
		ExternalObject = ModuleAdditionalReportsAndDataProcessors.GetObjectOfExternalDataProcessor(RefToDataProcessor);
	EndIf;
	
	ExternalObject.DefineDataLoadFromFileParameters(CommandName, ImportParameters);
	
	ImportParameters.Insert("Template", ExternalObject.TemplateWithTemplate(ImportParameters.TemplateNameWithTemplate));
	
	Return ImportParameters;
EndFunction

#EndRegion

#Region ServiceFunctions

Procedure CreateCatalogsListForImport(CatalogsListForImport) Export
	
	StringType = New TypeDescription("String");
	BooleanType = New TypeDescription("Boolean");

	InformationAboutCatalogs = New ValueTable;
	InformationAboutCatalogs.Columns.Add("FullName", StringType);
	InformationAboutCatalogs.Columns.Add("Presentation", StringType);
	InformationAboutCatalogs.Columns.Add("AppliedImport", BooleanType);
	
	For Each MetadataObjectForOutput IN Metadata.Catalogs Do
		If Not CatalogContainsAttributeException(MetadataObjectForOutput) Then
			String = InformationAboutCatalogs.Add();
			String.Presentation = MetadataObjectForOutput.Presentation();
			String.FullName = MetadataObjectForOutput.FullName();
		EndIf;
	EndDo;
	
	StandardSubsystemsIntegration.OnDetermineCatalogsForDataImport(InformationAboutCatalogs);
	DataLoadFromFileOverridable.OnDetermineCatalogsForDataImport(InformationAboutCatalogs);
	
	InformationAboutCatalogs.Columns.Add("InformationAboutImportType");
	
	For Each InformationAboutCatalog IN InformationAboutCatalogs Do
		InformationAboutImportType = New Structure;
		If InformationAboutCatalog.AppliedImport Then
			InformationAboutImportType.Insert("Type", "AppliedImport");
		Else
			InformationAboutImportType.Insert("Type", "UniversalImport");
		EndIf;
		InformationAboutImportType.Insert("FullMetadataObjectName", InformationAboutCatalog.FullName);
		InformationAboutCatalog.InformationAboutImportType = InformationAboutImportType;
	EndDo;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		Query = New Query;
		Query.Text =
		"SELECT
		|	AdditionalReportsAndDataProcessorsCommands.Ref,
		|	AdditionalReportsAndDataProcessorsCommands.ID,
		|	AdditionalReportsAndDataProcessorsCommands.Presentation,
		|	AdditionalReportsAndDataProcessorsCommands.Modifier
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors.Commands AS AdditionalReportsAndDataProcessorsCommands
		|WHERE
		|	AdditionalReportsAndDataProcessorsCommands.StartVariant = &StartVariant
		|	AND AdditionalReportsAndDataProcessorsCommands.Ref.Kind = &Kind
		|	AND Not AdditionalReportsAndDataProcessorsCommands.Ref.DeletionMark
		|	AND AdditionalReportsAndDataProcessorsCommands.Ref.Publication = &Publication";
		Query.SetParameter("StartVariant", Enums.AdditionalDataProcessorsCallMethods.DataLoadFromFile);
		Query.SetParameter("Kind", Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalInformationProcessor);
		Query.SetParameter("Publication", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used);
		CommandTable = Query.Execute().Unload();
		
		For Each TableRow IN CommandTable Do
			InformationAboutImportType = New Structure;
			InformationAboutImportType.Insert("Type", "OuterImport");
			InformationAboutImportType.Insert("FullMetadataObjectName", TableRow.ID);
			InformationAboutImportType.Insert("Ref", TableRow.Ref);
			InformationAboutImportType.Insert("TemplateWithTemplate", TableRow.Modifier);
			
			String = InformationAboutCatalogs.Add();
			String.FullName = MetadataObjectForOutput.FullName();
			String.InformationAboutImportType= InformationAboutImportType;
			String.Presentation = TableRow.Presentation;
		EndDo;
	EndIf;
	
	CatalogsListForImport.Clear();
	For Each string IN InformationAboutCatalogs Do 
		CatalogsListForImport.Add(String.InformationAboutImportType, String.Presentation);
	EndDo;
		
	CatalogsListForImport.SortByPresentation();
	
EndProcedure 

Function CatalogContainsAttributeException(Catalog)
	
	For Each Attribute IN Catalog.TabularSections Do
		If Attribute.Name <> "ContactInformation" AND
			Attribute.Name <> "AdditionalAttributes" AND
			Attribute.Name <> "EncryptionCertificates" Then
				Return True;
		EndIf;
	EndDo;
	
	For Each Attribute IN Catalog.Attributes Do 
		For Each AttributeType IN Attribute.Type.Types() Do
			If AttributeType = Type("ValueStorage") Then
				Return True;
			EndIf;
		EndDo;
	EndDo;
	
	If Title(Left(Catalog.Name, 7)) = "Delete" Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

#Region SearchRefs

Procedure InitializeSearchRefsMode(TemplateWithData, InformationByColumns, TypeDescription) Export
	ColumnsMatch = New Map;
	ColumnsTitle = "";
	Delimiter = "";
	
	For Each Type IN TypeDescription.Types() Do 
		MetadataObject = Metadata.FindByType(Type);
		StructureObject = DecomposeFullObjectName(MetadataObject.FullName());
		
		For Each Column IN MetadataObject.InputByString Do 
			If ColumnsMatch.Get(Column.Name) = Undefined Then 
				
				ColumnsTitle = ColumnsTitle + Delimiter +Column.Name;
				Delimiter = ", ";
				ColumnsMatch.Insert(Column.Name, Column.Name);
			EndIf;
		EndDo;
		If StructureObject.ObjectType = "Document" Then 
			ColumnsTitle = ColumnsTitle + Delimiter + "Presentation";
		EndIf;
		
		ColumnsTitle = NStr("en='Entered data';ru='Введенные данные'");
		
	EndDo;
	
	AddInformationByColumn(InformationByColumns, "Refs", ColumnsTitle, New TypeDescription("String"), False, 1);
	
	Header = FormHeaderToFillByInformationByColumns(InformationByColumns);
	TemplateWithData.Clear();
	TemplateWithData.Put(Header);
	
	
EndProcedure

Procedure MatchAutoColumnValue(MappingTable, ColumnName) Export
	
	Types = MappingTable.Columns.MappingObject.ValueType.Types();
	QueryText = "";
	For Each Type IN Types Do
		MetadataObject = Metadata.FindByType(Type);
		StructureObject = DecomposeFullObjectName(MetadataObject.FullName());
		
		ColumnArray = New Array;
		For Each Field IN MetadataObject.InputByString Do
			ColumnArray.Add(Field.Name);
		EndDo;
		If StructureObject.ObjectType = "Document" Then
			ColumnArray.Add("Ref");
		EndIf;
		
		QueryText = QueryString(QueryText, StructureObject.ObjectType,
		StructureObject.NameObject, ColumnArray);
	EndDo;
	
	For Each String IN MappingTable Do 
		If Not ValueIsFilled(String[ColumnName]) Then 
			Continue;
		EndIf;
		
		If ValueIsFilled(QueryText) Then
			Value = DocumentByPresentation(String[ColumnName], Types);
			If Value = Undefined Then
				Value = String[ColumnName];
			EndIf;
			RefArray = FindRefsByFilterParameters(QueryText, Value);
			If RefArray.Count() = 1 Then
				String.MappingObject = RefArray[0];
				String.RowMatchResult = "RowMatched";
			ElsIf RefArray.Count() > 1 Then
				AmbiguitiesList = New ValueList;
				String.AmbiguitiesList.LoadValues(RefArray);
				String.RowMatchResult = "Ambiguity";
			Else
				String.RowMatchResult = "NotMatched";
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Recognizes a document by presentation for the references search mode.
//
Function DocumentByPresentation(Presentation, Types)
	
	For Each Type IN Types Do 
		MetadataObject = Metadata.FindByType(Type);
		ObjectNameStructure = DecomposeFullObjectName(MetadataObject.FullName());
		If ObjectNameStructure.ObjectType <> "Document" Then
			Continue;
		EndIf;
		
		StandardProperties = New Structure("ObjectPresentation, ExtendedObjectPresentation, ListPresentation, ExtendedListPresentation");
		FillPropertyValues(StandardProperties, MetadataObject);
		
		If ValueIsFilled(StandardProperties.ObjectPresentation) Then
			ItemPresentation = StandardProperties.ObjectPresentation;
		ElsIf ValueIsFilled(StandardProperties.ExtendedObjectPresentation) Then
			ItemPresentation = StandardProperties.ExtendedObjectPresentation;
		Else
			ItemPresentation = MetadataObject.Presentation();
		EndIf;
		
		If Find(Presentation, ItemPresentation) > 0 Then
			PresentationNumberAndDate = TrimAll(Mid(Presentation, StrLen(ItemPresentation) + 1));
			EndNumberPosition = Find(PresentationNumberAndDate, " ");
			Number = Left(PresentationNumberAndDate, EndNumberPosition - 1);
			PositionFrom = Find(Lower(PresentationNumberAndDate), "from");
			PresentationDate = TrimL(Mid(PresentationNumberAndDate, PositionFrom + 2));
			DateEndPosition = Find(PresentationDate, " ");
			DateRoundedToDay = Left(PresentationDate, DateEndPosition - 1) + " 00:00:00";
			NumberDocument = Number;
			DocumentDate = ConvertToDate(DateRoundedToDay);
		EndIf;
		Document = Documents[MetadataObject.Name].FindByNumber(NumberDocument, DocumentDate);
		
		If Not (Document = Undefined OR Document = Documents[MetadataObject.Name].EmptyRef()) Then
			Return Document;
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

Function QueryString(QueryText, ObjectType, ObjectName, ColumnArray)
	
	If ColumnArray.Count() > 0 Then
		TextWhere = "";
		SeparatorWhere = "";
		For Each Field IN ColumnArray Do 
			TextWhere = TextWhere + SeparatorWhere + ObjectName + "." + Field + " = &SearchParameter";
			SeparatorWhere = " OR ";
		EndDo;
		
		TextTemplate = "SELECT %1.Ref AS ObjectReference FROM %2.%1 AS %1 WHERE " + TextWhere;
		If ValueIsFilled(QueryText) Then 
			UnionAllText = Chars.LF + "UNION ALL" + Chars.LF;
		Else
			UnionAllText = "";
		EndIf;
		QueryText = QueryText + UnionAllText + StringFunctionsClientServer.PlaceParametersIntoString(TextTemplate, ObjectName, ObjectType);
	EndIf;
	Return QueryText;
	
EndFunction

Function FindRefsByFilterParameters(QueryText, Value)
	Query = New Query(QueryText);
	Query.SetParameter("SearchParameter", Value);
	
	TableOfResults = Query.Execute().Unload();
	ResultArray = TableOfResults.UnloadColumn("ObjectReference");
	Return ResultArray;
EndFunction

// Add information by column for the references search mode.
//
Procedure AddInformationByColumn(InformationByColumns, Name, Presentation, Type, ObligatoryToComplete, Position, Association = "")
	RowInfoAboutColumns = InformationByColumns.Add();
	RowInfoAboutColumns.ColumnName = Name;
	RowInfoAboutColumns.ColumnPresentation = Presentation;
	RowInfoAboutColumns.ColumnType = Type;
	RowInfoAboutColumns.ObligatoryToComplete = ObligatoryToComplete;
	RowInfoAboutColumns.Position = Position;
	RowInfoAboutColumns.Association = ?(ValueIsFilled(Association), Association, Name);
	RowInfoAboutColumns.Visible = True;
EndProcedure

#EndRegion

// Fills values table matched data by the template data.
//
Procedure FillMatchTableWithDataFromTemplateBackground(ExportParameters, StorageAddress) Export
	
	TemplateWithData = ExportParameters.TemplateWithData;
	MappingTable = ExportParameters.MappingTable;
	InformationByColumns = ExportParameters.InformationByColumns;
	
	MappingTable.Clear();
	FillMatchTableWithImportedData(TemplateWithData, InformationByColumns, MappingTable, True);
	
	PutToTempStorage(MappingTable, StorageAddress);
	
EndProcedure

Procedure FillDataMatchTableWithDataFromTemplate(TemplateWithData, MappingTable, InformationByColumns) Export
	
	DefineColumnPositionsInTemplate(TemplateWithData, InformationByColumns);
	MappingTable.Clear();
	FillMatchTableWithImportedData(TemplateWithData, InformationByColumns, MappingTable);
	
EndProcedure

Procedure FillMatchTableWithImportedData(TemplateWithData, TableInformationByColumns, MappingTable, BackgroundJob = False)
	
	IDAdjustment = 0;
	For LineNumber = 2 To TemplateWithData.TableHeight Do 
		EmptyTableRow = True;
		NewRow = MappingTable.Add();
		NewRow.ID = LineNumber - 1 - IDAdjustment;
		NewRow.RowMatchResult = "NotMatched";
		
		For ColumnNumber = 1 To TemplateWithData.TableWidth Do
			
			Cell = TemplateWithData.GetArea(LineNumber, ColumnNumber, LineNumber, ColumnNumber).CurrentArea;
			Column = FindInformationAboutColumn(TableInformationByColumns, "Position", ColumnNumber);
			
			If Column <> Undefined Then
				ColumnName = Column.ColumnName;
				DataType = TypeOf(NewRow[ColumnName]);
				
				If DataType <> Type("String") AND DataType <> Type("Boolean") AND DataType <> Type("Number") AND DataType <> Type("Date")  AND DataType <> Type("UUID") Then 
					GivenCells = CellValue(Column, Cell.Text);
				Else
					GivenCells = Cell.Text;
				EndIf;
				If EmptyTableRow Then
					EmptyTableRow = Not ValueIsFilled(GivenCells);
				EndIf;
				NewRow[ColumnName] = GivenCells;
			EndIf;
		EndDo;
		If EmptyTableRow Then
			MappingTable.Delete(NewRow);
			IDAdjustment = IDAdjustment + 1;
		EndIf;
		
		If BackgroundJob Then
			Percent = Round(LineNumber *100 / TemplateWithData.TableHeight);
			LongActionsModule = CommonUse.CommonModule("LongActions");
			LongActionsModule.TellProgress(Percent);
		EndIf;
		
	EndDo;
	
EndProcedure

Function CellValue(Column, CellValue)
	
	GivenCells = "";
	For Each DataType IN Column.ColumnType.Types() Do 
		Object = Metadata.FindByType(DataType);
		ObjectDescription = DecomposeFullObjectName(Object.FullName());
		If ObjectDescription.ObjectType = "Catalog" Then
			If Not Object.AutoNumber AND Object.CodeLength > 0 Then 
				GivenCells = Catalogs[ObjectDescription.NameObject].FindByCode(CellValue, True);
			EndIf;
			If Not ValueIsFilled(GivenCells) Then 
				GivenCells = Catalogs[ObjectDescription.NameObject].FindByDescription(CellValue, True);
			EndIf;
			If Not ValueIsFilled(GivenCells) Then 
				GivenCells = Catalogs[ObjectDescription.NameObject].FindByCode(CellValue, True);
			EndIf;
		ElsIf ObjectDescription.ObjectType = "Enum" Then 
			For Each EnumValue IN Enums[ObjectDescription.NameObject] Do 
				If String(EnumValue) = TrimAll(CellValue) Then 
					GivenCells = EnumValue; 
				EndIf;
			EndDo;
		ElsIf ObjectDescription.ObjectType = "ChartOfAccounts" Then
			GivenCells = ChartsOfAccounts[ObjectDescription.NameObject].FindByCode(CellValue);
			If GivenCells.IsEmpty() Then 
				GivenCells = ChartsOfAccounts[ObjectDescription.NameObject].FindByDescription(CellValue, True);
			EndIf;
		ElsIf ObjectDescription.ObjectType = "ChartOfCharacteristicTypes" Then
			If Not Object.AutoNumber AND Object.CodeLength > 0 Then 
				GivenCells = ChartsOfCharacteristicTypes[ObjectDescription.NameObject].FindByCode(CellValue, True);
			EndIf;
			If Not ValueIsFilled(GivenCells) Then 
				GivenCells = ChartsOfCharacteristicTypes[ObjectDescription.NameObject].FindByDescription(CellValue, True);
			EndIf;
		Else
			GivenCells =  String(CellValue);
		EndIf;
		If ValueIsFilled(GivenCells) Then 
			Break;
		EndIf;
	EndDo;
	
	Return GivenCells;
	
EndFunction

Procedure DefineColumnPositionsInTemplate(TemplateWithData, InformationByColumns)
	
	TitleArea = TableTemplateTitleArea(TemplateWithData);
	
	ColumnsMatch = New Map;
	For ColumnNumber = 1 To TitleArea.TableWidth Do 
		Cell=TemplateWithData.GetArea(1, ColumnNumber, 1, ColumnNumber).CurrentArea;
		ColumnNameInTemplate = Cell.Text;
		ColumnsMatch.Insert(ColumnNameInTemplate, ColumnNumber);
	EndDo;
	
	For Each Column IN InformationByColumns Do 
		Position = ColumnsMatch.Get(Column.ColumnPresentation);
		If Position <> Undefined Then 
			Column.Position = Position;
		Else
			Column.Position = -1;
		EndIf;
	EndDo;
	
EndProcedure


#Region PreparationForDataImport

Function TableTemplateTitleArea(Pattern)
	MetadataAreaTableTitle = Pattern.Areas.Find("Header");
	
	If MetadataAreaTableTitle = Undefined Then 
		AreaTitleTables = Pattern.GetArea("R1");
	Else 
		AreaTitleTables = Pattern.GetArea("Header"); 
	EndIf;
	
	Return AreaTitleTables;
	
EndFunction

// Forms template of a tabular document based on the attributes of catalog for a universal import.
//
Procedure InformationOnColumnsFromCatalogAttributes(ImportParameters, InformationByColumns) Export
	
	NoteText = "";
	InformationByColumns.Clear();
	Position = 1;
	TypeDescriptionString = New TypeDescription("String");
	
	CatalogMetadata= Metadata.FindByFullName(ImportParameters.FullObjectName);
	
	If Not CatalogMetadata.AutoNumber AND CatalogMetadata.CodeLength > 0  Then
		CreateColumnStandardAttributes(InformationByColumns, CatalogMetadata, "Code", Position);
		Position = Position + 1;
	EndIf;
	
	If CatalogMetadata.DescriptionLength > 0  Then
		CreateColumnStandardAttributes(InformationByColumns, CatalogMetadata, "Description", Position);
		Position = Position + 1;
	EndIf;
	
	If CatalogMetadata.Hierarchical Then
		 CreateColumnStandardAttributes(InformationByColumns, CatalogMetadata, "Parent", Position);
		 Position = Position + 1;
	EndIf;
	 
	If CatalogMetadata.Owners.Count() > 0 Then
		 CreateColumnStandardAttributes(InformationByColumns, CatalogMetadata, "Owner", Position);
		 Position = Position + 1;
	EndIf;
	
	For Each Attribute IN CatalogMetadata.Attributes Do
		
		If Attribute.Type.ContainsType(Type("ValueStorage")) Then
			Continue;
		EndIf;
		
		ColumnTypeDescription = "";
		
		If Attribute.Type.ContainsType(Type("Boolean")) Then 
			ColumnTypeDescription = NStr("en='Check box, Yes or 1 / No or 0';ru='Флаг, Да или 1 / Нет или 0'");
		ElsIf Attribute.Type.ContainsType(Type("Number")) Then 
			ColumnTypeDescription =  StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Number, Length: %1, Accuracy: %2';ru='Число, Длина: %1, Точность: %2'"),
			String(Attribute.Type.NumberQualifiers.Digits),
			String(Attribute.Type.NumberQualifiers.FractionDigits));
		ElsIf Attribute.Type.ContainsType(Type("String")) Then
			If Attribute.Type.StringQualifiers.Length > 0 Then
				StringLength = String(Attribute.Type.StringQualifiers.Length);
				ColumnTypeDescription =  StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='String, max. quantity of symbols: %1';ru='Строка, макс. количество символов: %1'"), StringLength);
			Else
				ColumnTypeDescription = NStr("en='Row of an unlimited length';ru='Строка неограниченной длины'");
			EndIf;
		ElsIf Attribute.Type.ContainsType(Type("Date")) Then
			ColumnTypeDescription =  StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='%1';ru='%1'"),String(Attribute.Type.DateQualifiers.DateFractions));
		ElsIf Attribute.Type.ContainsType(Type("UUID")) Then 
			ColumnTypeDescription = NStr("en='UUID';ru='UUID'");
		EndIf;
		
		ColumnWidth = ColumnWidthByType(Attribute.Type);
		ToolTip = ?(ValueIsFilled(Attribute.ToolTip), Attribute.ToolTip, Attribute.Presentation()) +  Chars.LF + ColumnTypeDescription;
		MandatoryField = ?(Attribute.FillChecking = FillChecking.ShowError, True, False);
		
		RowInfoAboutColumns = InformationByColumns.Add();
		RowInfoAboutColumns.ColumnName = Attribute.Name;
		RowInfoAboutColumns.ColumnPresentation = Attribute.Presentation();
		RowInfoAboutColumns.ColumnType = Attribute.Type;
		RowInfoAboutColumns.ObligatoryToComplete = MandatoryField;
		RowInfoAboutColumns.Position = Position;
		RowInfoAboutColumns.Visible = True;
		RowInfoAboutColumns.Note = ToolTip;
		RowInfoAboutColumns.Width = ColumnWidth;

		Position = Position + 1;
		
	EndDo;
	
EndProcedure

// Add information about a column for a standard attribute during a universal import.
//
Procedure CreateColumnStandardAttributes(InformationByColumns, CatalogMetadata, ColumnName, Position)
	
	Attribute = CatalogMetadata.StandardAttributes[ColumnName];
	Presentation = CatalogMetadata.StandardAttributes[ColumnName].Presentation();
	DataType = CatalogMetadata.StandardAttributes[ColumnName].Type.Types()[0];
	DescriptionOfType = CatalogMetadata.StandardAttributes[ColumnName].Type;
	
	ColumnWidth = 11;
	
	If DataType = Type("String") Then 
		TypePresentation = StringFunctionsClientServer.PlaceParametersIntoString(NStr("ru =  Row (no more than %1 characters)"), DescriptionOfType.StringQualifiers.Length);
		ColumnWidth = ?(DescriptionOfType.StringQualifiers.Length < 30, DescriptionOfType.StringQualifiers.Length + 1, 30);
	ElsIf DataType = Type("Number") Then	
		TypePresentation = NStr("en='Number';ru='Номер'");
	Else
		If CatalogMetadata.StandardAttributes[ColumnName].Type.Types().Count() = 1 Then 
			TypePresentation = String(DataType); 
		Else
			TypePresentation = "";
			Delimiter = "";
			For Each TypeData IN CatalogMetadata.StandardAttributes[ColumnName].Type.Types() Do 
				TypePresentation = TypePresentation  + Delimiter + String(TypeData);
				Delimiter = " or ";
			EndDo;
		EndIf;
	EndIf;
	NoteText = Attribute.ToolTip + Chars.LF + TypePresentation;
	
	ObligatoryToComplete = ?(Attribute.FillChecking = FillChecking.ShowError, True, False);
	RowInfoAboutColumns = InformationByColumns.Add();
	RowInfoAboutColumns.ColumnName = ColumnName;
	RowInfoAboutColumns.ColumnPresentation = Presentation;
	RowInfoAboutColumns.ColumnType = DescriptionOfType;
	RowInfoAboutColumns.ObligatoryToComplete = ObligatoryToComplete;
	RowInfoAboutColumns.Position = Position;
	RowInfoAboutColumns.Visible = True;
	RowInfoAboutColumns.Note = NoteText;
	RowInfoAboutColumns.Width = ColumnWidth;
	
EndProcedure

// Defines a content of columns for data import.
//
Procedure DefineInformationByColumns(ImportParameters, InformationByColumns, AddedColumnNames = Undefined) Export
	
	If ImportParameters.ImportType = "AppliedImport" Then
		If ImportParameters.Property("Template") Then
			Template = ImportParameters.Template;
		Else
			Template = ObjectManager(ImportParameters.FullObjectName).GetTemplate("LoadFromFile");
		EndIf;
		AreaTitleTables = TableTemplateTitleArea(Template);
		If InformationByColumns.Count() = 0 Then 
			CreateInformationByColumnsBasedOnTemplate(AreaTitleTables, ImportParameters, InformationByColumns, Undefined);
		EndIf;
	ElsIf ImportParameters.ImportType = "UniversalImport" Then
		InformationByColumnsBasedOnAttributes = InformationByColumns.CopyColumns();
		If InformationByColumns.Count() = 0 Then
			InformationOnColumnsFromCatalogAttributes(ImportParameters, InformationByColumns);
		Else
			InformationOnColumnsFromCatalogAttributes(ImportParameters, InformationByColumnsBasedOnAttributes);
		EndIf;
	ElsIf ImportParameters.ImportType = "OuterImport" AND InformationByColumns.Count() = 0 Then
		AreaTitleTables = TableTemplateTitleArea(ImportParameters.Template);
		AreaTitleTables.Protection = True;
		If InformationByColumns.Count() = 0 Then
			CreateInformationByColumnsBasedOnTemplate(AreaTitleTables, ImportParameters, InformationByColumns);
		EndIf;
	ElsIf ImportParameters.ImportType = "TabularSection" AND InformationByColumns.Count() = 0 Then
		AreaTitleTables = TableTemplateTitleArea(ImportParameters.Template);
	EndIf;
	
	PositionsRecalculationRequired = False;
	ColumnsListWithFunctionalOptions = ColumnsDependentOnFunctionalOptions(ImportParameters.FullObjectName);
	For Each FunctionalOptionColumnsEnabled IN ColumnsListWithFunctionalOptions Do 
		RowWithInformationAboutColumn = InformationByColumns.Find(FunctionalOptionColumnsEnabled.Key, "ColumnName");
		If RowWithInformationAboutColumn <> Undefined Then
			If Not FunctionalOptionColumnsEnabled.Value Then
				InformationByColumns.Delete(RowWithInformationAboutColumn);
				PositionsRecalculationRequired = True;
			EndIf;
		Else
			If FunctionalOptionColumnsEnabled.Value Then
				If ImportParameters.ImportType = "UniversalImport" Then
					RowWithColumn = InformationByColumnsBasedOnAttributes.Find(FunctionalOptionColumnsEnabled.Key, "ColumnName");
					NewRow = InformationByColumns.Add();
					FillPropertyValues(NewRow, RowWithColumn);
				Else
					CreateInformationByColumnsBasedOnTemplate(AreaTitleTables, ImportParameters, InformationByColumns, FunctionalOptionColumnsEnabled.Key);
				EndIf;
				PositionsRecalculationRequired = True;
			EndIf;
		EndIf;
	EndDo;
	
	If PositionsRecalculationRequired Then
		InformationByColumns.Sort("Position");
		Position = 1;
		For Each Column IN InformationByColumns Do
			Column.Position = Position;
			Position = Position + 1;
		EndDo;
	EndIf;
	
EndProcedure

// Fills columns table in the template. The information is used to build a match table.
//
// Parameters:
//  AreaTitleTables	 - TextDocument - Template title area.
//  ImportParametersFromFile - Structure - Import parameters.
//  InformationByColumns	 - ValueTable - Table with columns description.
//  AddedColumnNames	 - String - list of added columns separated by commas. If the value is
//                                      not filled, then all values are added.
Procedure CreateInformationByColumnsBasedOnTemplate(AreaTitleTables, ImportParametersFromFile, InformationByColumns, AddedColumnNames = Undefined) Export
	
	SelectiveAdding = False;
	If ValueIsFilled(AddedColumnNames) Then
		SelectiveAdding = True;
		AddedColumnsArray = StringFunctionsClientServer.SplitStringIntoWordArray(AddedColumnNames, ",");
		Position = InformationByColumns.Count() + 1;
	Else
		InformationByColumns.Clear();
		Position = 1;
	EndIf;
	
	If ImportParametersFromFile.Property("DataTypeColumns") Then
		ColumnsDataTypeMatch = ImportParametersFromFile.DataTypeColumns;
	Else
		ColumnsDataTypeMatch = New Map;
	EndIf;
	
	ColumnsListWithFunctionalOptions = ColumnsDependentOnFunctionalOptions(ImportParametersFromFile.FullObjectName);
	
	For ColumnNumber = 1 To AreaTitleTables.TableWidth Do
		Cell = AreaTitleTables.GetArea(1, ColumnNumber, 1, ColumnNumber).CurrentArea;
		
		If Find(Cell.Name, "R") > 0 AND Find(Cell.Name, "C") > 0 Then
			AttributeName = ?(ValueIsFilled(Cell.DetailsParameter), Cell.DetailsParameter, Cell.Text);
			AttributePresentation = ?(ValueIsFilled(Cell.Text), Cell.Text, Cell.DetailsParameter);
			Association = ?(ValueIsFilled(Cell.DetailsParameter), Cell.DetailsParameter, Cell.Text);
		Else	
			AttributeName = Cell.Name;
			AttributePresentation = ?(ValueIsFilled(Cell.Text), Cell.Text, Cell.Name);
			Association = ?(ValueIsFilled(Cell.DetailsParameter), Cell.DetailsParameter, Cell.Name);
		EndIf;
		
		DataTypeColumns = New TypeDescription("String");
		If ColumnsDataTypeMatch <> Undefined Then
			DataTypeColumnsPredefined = ColumnsDataTypeMatch.Get(AttributeName);
			If DataTypeColumnsPredefined <> Undefined Then
				DataTypeColumns = DataTypeColumnsPredefined;
			EndIf;
		EndIf;
		
		If SelectiveAdding AND AddedColumnsArray.Find(AttributeName) = Undefined Then
			Continue;
		EndIf;
		
		If ValueIsFilled(AttributeName) Then
			RowInfoAboutColumns = InformationByColumns.Add();
			RowInfoAboutColumns.ColumnName = AttributeName;
			RowInfoAboutColumns.ColumnPresentation = AttributePresentation;
			RowInfoAboutColumns.ColumnType = DataTypeColumns;
			RowInfoAboutColumns.ObligatoryToComplete = Cell.Font.Bold;
			RowInfoAboutColumns.Position = Position;
			RowInfoAboutColumns.Association = ?(ValueIsFilled(Association), Association, AttributeName);
			RowInfoAboutColumns.Visible = True;
			RowInfoAboutColumns.Note = Cell.Note.Text;
			RowInfoAboutColumns.Width = Cell.ColumnWidth;
			Position = Position + 1;
		EndIf;
	EndDo;
	
EndProcedure

Function ColumnWidthByType(Type) 
	
	ColumnWidth = 20;
	If Type.ContainsType(Type("Boolean")) Then 
		ColumnWidth = 3;
	ElsIf Type.ContainsType(Type("Number")) Then 
		ColumnWidth = Type.NumberQualifiers.Digits + 1;
	ElsIf Type.ContainsType(Type("String")) Then 
		If Type.StringQualifiers.Length > 0 Then 
			ColumnWidth = ?(Type.StringQualifiers.Length > 20, 20, Type.StringQualifiers.Length);
		Else
			ColumnWidth = 20;
		EndIf;
	ElsIf Type.ContainsType(Type("Date")) Then 
		ColumnWidth = 12;
	ElsIf Type.ContainsType(Type("UUID")) Then 
		ColumnWidth = 20;
	Else
		For Each ObjectType IN  Type.Types() Do
			ObjectMetadata = Metadata.FindByType(ObjectType);
			StructureObject = DecomposeFullObjectName(ObjectMetadata.FullName());
			If StructureObject.ObjectType = "Catalog" Then 
				If Not ObjectMetadata.AutoNumber AND ObjectMetadata.CodeLength > 0  Then
					ColumnWidth = ObjectMetadata.CodeLength + 1;
				EndIf;
				If ObjectMetadata.DescriptionLength > 0  Then
					If ObjectMetadata.DescriptionLength > ColumnWidth Then
						ColumnWidth = ?(ObjectMetadata.DescriptionLength > 30, 30, ObjectMetadata.DescriptionLength + 1);
					EndIf;
			EndIf;
		ElsIf StructureObject.ObjectType = "Enum" Then
				PresentationLength =  StrLen(ObjectMetadata.Presentation());
				ColumnWidth = ?( PresentationLength > 30, 30, PresentationLength + 1);
			EndIf;
		EndDo;
	EndIf;
	
	Return ColumnWidth;
	
EndFunction

Procedure FillCellTemplateTitle(Cell, Text, Width, ToolTip, MandatoryField, Name = "") Export
	
	Cell.CurrentArea.Text = Text;
	Cell.CurrentArea.Name = Name;
	Cell.CurrentArea.DetailsParameter = Name;
	Cell.CurrentArea.BackColor =  StyleColors.ReportHeaderBackColor;
	Cell.CurrentArea.ColumnWidth = Width;
	Cell.CurrentArea.Note.Text = ToolTip;
	If MandatoryField Then 
		Cell.CurrentArea.Font = New Font(,,True);
	Else
		Cell.CurrentArea.Font = New Font(,,False);
	EndIf;
	
EndProcedure

Procedure InitializeImportToTabularSection(TabularSectionFullName, TemplateNameWithTemplate, InformationByColumns, TemplateWithData, AdditionalParameters, Cancel) Export
	
	StructureObjectName = DecomposeFullObjectName(TabularSectionFullName);
	ImportParametersFromFile = LoadFromFileToTPParameters(TabularSectionFullName, AdditionalParameters);
	ImportParametersFromFile.Insert("FullObjectName", TabularSectionFullName);
	
	If StructureObjectName.ObjectType = "Document" Then
		ObjectManager = Documents[StructureObjectName.NameObject];
		
		ObjectManager.SetImportParametersFromFileToTP(ImportParametersFromFile);
		
		If ImportParametersFromFile.Property("TemplateNameWithTemplate") AND ValueIsFilled(ImportParametersFromFile.TemplateNameWithTemplate) Then
			TemplateNameWithTemplate = ImportParametersFromFile.TemplateNameWithTemplate;
		EndIf;
		
		TemplateMetadata = Metadata.Documents[StructureObjectName.NameObject].Templates.Find(TemplateNameWithTemplate);
		If TemplateMetadata = Undefined Then 
			TemplateMetadata= Metadata.Documents[StructureObjectName.NameObject].Templates.Find("LoadFromFile" + StructureObjectName.TabularSectionName);
			If TemplateMetadata = Undefined Then 
				TemplateMetadata = Metadata.Documents[StructureObjectName.NameObject].Templates.Find("LoadFromFile");
			EndIf;
		EndIf;
		
		If TemplateMetadata <> Undefined Then
			Template = ObjectManager.GetTemplate(TemplateMetadata.Name);
		Else
			Raise NStr("en='Template for data import from a file is not found.';ru='Не найден макет для загрузки данных из файла'");
			Cancel = True;
			Return;
		EndIf;
		
		TableTitle = TableTemplateTitleArea(Template);
		If InformationByColumns.Count() = 0 Then
			CreateInformationByColumnsBasedOnTemplate(TableTitle, ImportParametersFromFile, InformationByColumns);
		EndIf;
		
		ColumnsListWithFunctionalOptions = ColumnsDependentOnFunctionalOptions(TabularSectionFullName);
		For Each FunctionalOptionColumnsEnabled IN ColumnsListWithFunctionalOptions Do 
			RowWithInformationAboutColumn = InformationByColumns.Find(FunctionalOptionColumnsEnabled.Key, "ColumnName");
			If RowWithInformationAboutColumn <> Undefined Then
				If Not FunctionalOptionColumnsEnabled.Value Then
					InformationByColumns.Delete(RowWithInformationAboutColumn);
				EndIf;
			Else
				If FunctionalOptionColumnsEnabled.Value Then
					CreateInformationByColumnsBasedOnTemplate(TableTitle, ImportParametersFromFile, InformationByColumns, FunctionalOptionColumnsEnabled.Key);
				EndIf;
			EndIf;
		EndDo;
		
		InformationByColumns.Sort("Position");
		Position = 1;
		For Each Column IN InformationByColumns Do
			Column.Position = Position;
			Position = Position + 1;
		EndDo;
		
		TemplateWithData.Put(TableTitle);
	EndIf; 
	
EndProcedure

// Creates a header of form by columns information.
//
Function FormHeaderToFillByInformationByColumns(InformationByColumns, WithNotes = True) Export

	SpreadsheetDocument = New SpreadsheetDocument;
	
	SimpleTemplate = DataProcessors.DataLoadFromFile.GetTemplate("SimpleTemplate");
	HeaderArea = SimpleTemplate.GetArea("Title");
	InformationByColumns.Sort("Position");
	
	For Position = 0 To InformationByColumns.Count() -1 Do
		Column = InformationByColumns.Get(Position);
		
		If Column.Visible = True Then
			HeaderArea.CurrentArea.Name = Column.ColumnName;
			HeaderArea.CurrentArea.Details = Column.Association;
			If ValueIsFilled(Column.Synonym) Then 
				HeaderArea.Parameters.Title = Column.Synonym;
			Else
				HeaderArea.Parameters.Title = Column.ColumnPresentation;
			EndIf;
			If Column.ObligatoryToComplete Then
				HeaderArea.CurrentArea.Font = New Font(,, True);
			Else
				HeaderArea.CurrentArea.Font = New Font(,, False);
			EndIf;
			If Column.Width = 0 Then 
				HeaderArea.CurrentArea.ColumnWidth = ColumnWidthByType(Column.ColumnType);
			Else
				HeaderArea.CurrentArea.ColumnWidth = Column.Width; 
			EndIf;
			If WithNotes Then
				HeaderArea.CurrentArea.Note.Text = Column.Note;
			EndIf;
			SpreadsheetDocument.Join(HeaderArea);
		EndIf;
	EndDo;
	
	Return SpreadsheetDocument;
EndFunction

#EndRegion

// Creates a values table according to the template data and saves it to the temporary storage.
//
Procedure ExportDataForTP(TemplateWithData, InformationByColumns, ImportedDataAddress) Export
	
	ExportableData = New ValueTable;
	TitleArea = TableTemplateTitleArea(TemplateWithData);
	
	For Each Column IN InformationByColumns Do 
		ExportableData.Columns.Add(Column.ColumnName, New TypeDescription("String"), Column.ColumnPresentation);
	EndDo;
	TypeDescriptionNumber = New TypeDescription("Number");
	TypeDescriptionRow = New TypeDescription("String");
	ExportableData.Columns.Add("ID",TypeDescriptionNumber, "ID");
	ExportableData.Columns.Add("RowMatchResult",TypeDescriptionRow, "Result");
	ExportableData.Columns.Add("ErrorDescription",TypeDescriptionRow, "Cause");
	
	IDAdjustment = 0;
	
	For LineNumber = 2 To TemplateWithData.TableHeight Do
		EmptyTableRow = True;
		NewRow = ExportableData.Add();
		NewRow.ID =  LineNumber - 1 - IDAdjustment;
		For ColumnNumber = 1 To TemplateWithData.TableWidth Do
			Cell = TemplateWithData.GetArea(LineNumber, ColumnNumber, LineNumber, ColumnNumber).CurrentArea;
			
			FoundColumn = FindInformationAboutColumn(InformationByColumns, "Position", ColumnNumber);
			If FoundColumn <> Undefined Then
				ColumnName = FoundColumn.ColumnName;
				NewRow[ColumnName] = Cell.Text;
				If EmptyTableRow Then
					EmptyTableRow = Not ValueIsFilled(Cell.Text);
				EndIf;
			EndIf;
		EndDo;
		If EmptyTableRow Then
			ExportableData.Delete(NewRow);
			IDAdjustment = IDAdjustment + 1;
		EndIf;
	EndDo;
	
	ImportedDataAddress = PutToTempStorage(ExportableData);
EndProcedure

Procedure FillTableByImportedDataFromFile(DataFromFile, TemplateWithData, InformationByColumns) Export 
	
	RowTitle= DataFromFile.Get(0);
	ColumnsMatch = New Map;
	
	For Each Column IN DataFromFile.Columns Do
		FoundColumn = FindInformationAboutColumn(InformationByColumns, "Synonym", RowTitle[Column.Name]);
		If FoundColumn = Undefined Then
			FoundColumn = FindInformationAboutColumn(InformationByColumns, "ColumnPresentation", RowTitle[Column.Name]);
		EndIf;
		If FoundColumn <> Undefined Then
			ColumnsMatch.Insert(FoundColumn.Position, Column.Name);
		EndIf;
	EndDo;
	
	For IndexOf= 1 To DataFromFile.Count() - 1 Do
		VTRow = DataFromFile.Get(IndexOf);
		
		For ColumnNumber =1 To TemplateWithData.TableWidth Do
			ColumnInTable = ColumnsMatch.Get(ColumnNumber);
			Column = InformationByColumns.Find(ColumnNumber, "Position");
			If Column <> Undefined AND Column.Visible = False Then
				Continue;
			EndIf;
			Cell = TemplateWithData.GetArea(2, ColumnNumber, 2, ColumnNumber);
			If ColumnInTable <> Undefined Then 
				Cell.CurrentArea.Text = VTRow[ColumnInTable];
				Cell.CurrentArea.TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
			Else
				Cell.CurrentArea.Text = "";
			EndIf;
			If ColumnNumber = 1 Then
				TemplateWithData.Put(Cell);
			Else
				TemplateWithData.Join(Cell);
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

///////////////// Common destination ///////////////////////////

Function ConvertToDate(Val DateString)
	
	DateString = TrimAll(StrReplace(DateString, ".", ""));
	DateString = Mid(DateString, 5) + Mid(DateString, 3, 2) + Left(DateString, 2);
	If StrLen(DateString) = 6 Then
		DateString = "20" + DateString;
	EndIf;
	
	DescriptionOfType = New TypeDescription("Date");
	Result    = DescriptionOfType.AdjustValue(DateString);
	
	Return Result;
	
EndFunction 

Function FindInformationAboutColumn(TableInformationByColumns, ColumnName, Value)
	
	Filter = New Structure(ColumnName, Value);
	FoundColumns = TableInformationByColumns.FindRows(Filter);
	Column = Undefined;
	If FoundColumns.Count() > 0 Then 
		Column = FoundColumns[0];
	EndIf;
	
	Return Column;
EndFunction

Function ObjectFullNameTabularSection(ObjectName) Export
	
	Result = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ObjectName,".");
	If Result.Count() = 4 Then
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
	ElsIf Result.Count() = 3 Then
		If Result[2] <> "TabularSection" Then 
			ObjectName = Result[0] + "." + Result[1] + ".TabularSection." + Result[2];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
		ElsIf Result[1] = "TabularSection" Then 
			ObjectName = "Document." + Result[0] + ".TabularSection." + Result[2];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			ObjectName = "Catalog." + Result[0] + ".TabularSection." + Result[2];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			Return Undefined;
		EndIf;
		
		Return Undefined;
	ElsIf Result.Count() = 2 Then
		If Result[0] <> "Document" OR Result[0] <> "Catalog" Then 
			ObjectName = "Document." + Result[0] + ".TabularSection." + Result[1];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			ObjectName = "Catalog." + Result[0] + ".TabularSection." + Result[1];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			Return Undefined;
		EndIf;
		MetadataObjectName = Result[0];
		TabularSectionName = Result[1];
		MetadataObjectType = Metadata.Catalogs.Find(MetadataObjectName);
		If MetadataObjectType <> Undefined Then 
			MetadataObjectType = "Catalog";
		Else
			MetadataObjectType = Metadata.Documents.Find(MetadataObjectName);					
			If MetadataObjectType <> Undefined Then 
				MetadataObjectType = "Document";
			Else 
				Return Undefined;
			EndIf;
		EndIf;
	EndIf;
	
	Return Undefined;	
	
EndFunction

// Returns the object name in structural form.
//
// Parameters:
// FullObjectName - Structure - Object name.
// 	* ObjectType - String - Object type.
// 	* ObjectName - String - Object name.
//		* TabularSectionName - String - Tabular section name.
Function DecomposeFullObjectName(FullObjectName) Export
	Result = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FullObjectName, ".");
	
	ObjectName = New Structure;
	ObjectName.Insert("FullObjectName", FullObjectName);
	ObjectName.Insert("ObjectType");
	ObjectName.Insert("NameObject");
	ObjectName.Insert("TabularSectionName");
	
	
	If Result.Count() = 2 Then
		If Result[0] = "Document" OR Result[0] = "Catalog" OR Result[0] = "BusinessProcess" OR
			Result[0] = "Enum" OR Result[0] = "ChartOfCharacteristicTypes" OR Result[0] = "ChartOfAccounts" Then
			ObjectName.ObjectType = Result[0];
			ObjectName.NameObject = Result[1];
		Else
			 ObjectName.ObjectType = DetermineMetadataObjectTypeByName(Result[0]);
			 ObjectName.NameObject = Result[0];
			 ObjectName.TabularSectionName = Result[1];
		EndIf;
	ElsIf Result.Count() = 3 Then
		ObjectName.ObjectType = Result[0];
		ObjectName.NameObject = Result[1];
		ObjectName.TabularSectionName = Result[2];
	ElsIf Result.Count() = 4 Then 
		ObjectName.ObjectType = Result[0];
		ObjectName.NameObject = Result[1];
		ObjectName.TabularSectionName = Result[3];
	ElsIf Result.Count() = 1 Then
		ObjectName.ObjectType = DetermineMetadataObjectTypeByName(Result[0]);
		ObjectName.NameObject = Result[0];
	EndIf;

	Return ObjectName;
	
EndFunction

Function DetermineMetadataObjectTypeByName(Name)
	For Each Object IN Metadata.Catalogs Do 
		If Object.Name = Name Then 
			Return "Catalog";
		EndIf;
	EndDo;
	
	For Each Object IN Metadata.Documents Do 
		If Object.Name = Name Then 
			Return "Document";
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

Function ObjectManager(CorrelationObjectName)
		ObjectArray = DataProcessors.DataLoadFromFile.DecomposeFullObjectName(CorrelationObjectName);
		If ObjectArray.ObjectType = "Document" Then
			ObjectManager = Documents[ObjectArray.NameObject];
		ElsIf ObjectArray.ObjectType = "Catalog" Then
			ObjectManager = Catalogs[ObjectArray.NameObject];
		Else
			Raise StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='%1 object is not found';ru='Объект ""%1"" не найден'"), CorrelationObjectName);
		EndIf;
		
		Return ObjectManager;
EndFunction

/////////////// Import data //////////////////////////

Procedure ImportFileIntoTable(ServerCallParameters, StorageAddress) Export
	
	Extension = ServerCallParameters.Extension;
	TemplateWithData = ServerCallParameters.TemplateWithData;
	TempFileName = ServerCallParameters.TempFileName;
	InformationByColumns = ServerCallParameters.InformationByColumns;
	
	If Extension = "xlsx" Then 
		ImportExcel2007FileToTable(TempFileName, TemplateWithData, InformationByColumns);
	ElsIf Extension = "csv" Then 
		ImportCSVFileToTable(TempFileName, TemplateWithData, InformationByColumns);
	Else
		TemplateWithData.Read(TempFileName);
	EndIf;
	
	StorageAddress = PutToTempStorage(TemplateWithData, StorageAddress);
	
EndProcedure

#Region ImportExcel2007FormatFiles

Procedure ImportExcel2007FileToTable(PathToFile, TemplateWithData, InformationByColumns) Export
	
	File = New File(PathToFile);
	If Not File.Exist() Then
		Return;
	EndIf;
	
	Table = TableFromExcel2007File(PathToFile);
	If Table <> Undefined Then
		FillTableByImportedDataFromFile(Table, TemplateWithData, InformationByColumns);
	EndIf;
	
EndProcedure

Function TableFromExcel2007File(PathToFile)
	
	TemporaryDirectory = TempFilesDir() + GetPathSeparator() + "excel2007";
	DeleteFiles(TemporaryDirectory);
	
	UnpackFile(PathToFile, TemporaryDirectory);
	
	RowsFile = TemporaryDirectory + GetPathSeparator() + "xl" + GetPathSeparator() +"sharedStrings.xml";
	RowList = ReadRowsList(RowsFile);
	
	FormatsFile = TemporaryDirectory + GetPathSeparator() + "xl" + GetPathSeparator() +"styles.xml";
	FormatList = ReadFormatsList(FormatsFile);
	
	NumberWorksheet = 1;
	SheetFile = TemporaryDirectory + GetPathSeparator() + "xl" + GetPathSeparator() + "worksheets" + GetPathSeparator() + "sheet" + NumberWorksheet + ".xml";
	File = New File(SheetFile);
	If Not File.Exist() Then
		Return Undefined;
	EndIf;
	
	LettersArray = GetLettersArray();
	DataTree = GetDataTree(SheetFile);
	
	Table = New ValueTable;
	
	// Create columns
	Columns = DataTree.Rows.Find("dimension", "Object", True);
	Counter = 0;
	For Each String IN Columns.Rows Do
		If String.Object = "ref" Then
			Range = String.Value; 
			// Search maximum value of the column.
			Counter = LettersArray.Count();
			While Counter > 0 Do 
				Counter = Counter - 1;
				If Find(Range, LettersArray[Counter]) > 0 Then
					For IndexOf = 0 To Counter Do
						Table.Columns.Add(LettersArray[IndexOf]);
					EndDo;
					Counter = 0;
				EndIf;
			EndDo;
			Break;
		EndIf;
	EndDo;
	
	// read rows
	RowsPag = DataTree.Rows.Find("sheetData", "Object", True);
	For Each String IN RowsPag.Rows Do
		NewRow = Table.Add();
		
		For Each Column IN String.Rows Do
			If Column.Object <> "c" Then
				Continue;
			EndIf;
			
			CellValue = Undefined;
			
			ValueStr = Column.Rows.Find("v", "Object");
			If ValueStr <> Undefined Then
				CellValue = ValueStr.Value;
			EndIf;
			
			CellContainsText = False;
			ValueStr = Column.Rows.Find("t", "Object");
			If ValueStr <> Undefined AND ValueStr.Value = "s" AND CellValue <> Undefined Then
				CellContainsText = True;
				Position = Number(CellValue); 
				If RowList.Count() > Position Then
					CellValue = RowList.Get(Position).Value;
				EndIf;
			EndIf;
			
			withObject = Column.Rows.Find("s", "Object");
			If withObject <> Undefined Then
				ValueStr = RowToNumber(Column.Rows.Find("s", "Object").Value, -1);
				If ValueStr >= 0 Then
					FormatName = FormatList.Get(ValueStr);
					If FormatName = "Date" OR FormatName = "DateTime" OR FormatName = "Time" Then
						If ValueIsFilled(CellValue) AND Not CellContainsText Then
							SeparatorPosition = Find(CellValue, ".");
							If SeparatorPosition > 0 Then 
								DaysNumber = RowToNumber(Left(CellValue, SeparatorPosition - 1)) * 86400 - 2 * 86400;
								CountSeconds = RowToNumber(Mid(CellValue, SeparatorPosition + 1)) - 2 * 60;
							Else
								DaysNumber = RowToNumber(CellValue) * 86400 - 2 * 86400;
								CountSeconds = 0;
							EndIf;
							ReceivedDate = Date(1900, 1, 1, 0, 0, 0) + DaysNumber + CountSeconds;
							If FormatName = "Date" Then 
								CellValue = Format(ReceivedDate, "DLF=D");
							ElsIf FormatName = "DateTime" Then 
								CellValue = Format(ReceivedDate, "DLF=DT");
							ElsIf FormatName = "Time" Then 
								CellValue = Format(ReceivedDate, "DLF=T");
							EndIf;
						EndIf;
					Else
						If FormatName = "Number" Then
							CellValueNumber = Format(RowToNumber(CellValue), "NGS=; NG=0");
							If Not ValueIsFilled(CellValueNumber) Then
								CellValue = Format(CellValue, "NGS=; NG=0");
							Else
								CellValue = CellValueNumber;
							EndIf;
						EndIf;
					EndIf;
				EndIf;
			EndIf;
			
			// search column
			ValueStr = Column.Rows.Find("r", "Object");
			If ValueStr <> Undefined Then
				ColumnName = ValueStr.Value;
			EndIf;
			RowIndex = Undefined;
			Counter = LettersArray.Count();
			While Counter > 0 Do 
				Counter = Counter - 1;
				If Find(ColumnName, LettersArray[Counter])>0 Then
					RowIndex = Counter;
					Counter = 0;
				EndIf;   
			EndDo;
			
			NewRow[LettersArray[RowIndex]] = CellValue;
		EndDo;
	EndDo;
	Return Table;
	
EndFunction

Procedure UnpackFile(File, Directory)
	archive = New ZipFileReader;
	archive.Open(File);
	archive.ExtractAll(Directory, ZIPRestoreFilePathsMode.Restore);
EndProcedure

Function GetLettersArray()
	LettersArray = New Array;
	LettersArray.Add("A");
	LettersArray.Add("B");
	LettersArray.Add("C");
	LettersArray.Add("D");
	LettersArray.Add("E");
	LettersArray.Add("F");
	LettersArray.Add("G");
	LettersArray.Add("H");
	LettersArray.Add("I");
	LettersArray.Add("J");
	LettersArray.Add("K");
	LettersArray.Add("L");
	LettersArray.Add("M");
	LettersArray.Add("N");
	LettersArray.Add("O");
	LettersArray.Add("P");
	LettersArray.Add("Q");
	LettersArray.Add("R");
	LettersArray.Add("S");
	LettersArray.Add("T");
	LettersArray.Add("U");
	LettersArray.Add("V");
	LettersArray.Add("W");
	LettersArray.Add("X");
	LettersArray.Add("Y");
	LettersArray.Add("Z");
	
	Return LettersArray;
EndFunction

Function ReadRowsList(RowsFile)
	
	Rows = New ValueList;
	ValueListItem	= Undefined;
	FilePresenceCheck	= New File(RowsFile);
	
	If FilePresenceCheck.Exist() Then
		
		XMLFile = New XMLReader;
		XMLFile.OpenFile(RowsFile);
		While XMLFile.Read() Do
			
			If XMLFile.NodeType = XMLNodeType.StartElement Then
				
				If XMLFile.Name = "sst" Then
					RecCount = XMLFile.GetAttribute("uniqueCount"); // Quantity of fields (not used at the current stage)
				ElsIf XMLFile.Name = "si" Then
					ValueListItem = Rows.Add("");
				EndIf;
				
			ElsIf XMLFile.NodeType = XMLNodeType.Text Then
				ValueListItem.Value = ValueListItem.Value + ?(ValueIsFilled(ValueListItem.Value), XMLFile.Value, TrimL(XMLFile.Value));
			EndIf;
			
		EndDo;
		XMLFile.Close();
		
	EndIf;
	Return Rows;
EndFunction

Function GetDataTree(File)
	
	DataTree = New ValueTree;
	DataTree.Columns.Add("Object");
	DataTree.Columns.Add("Value");
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(File);
	
	CurItem = Undefined;
	CurBase = Undefined;
	
	While XMLReader.Read() Do
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			ImportMode = XMLReader.Name;
			
			If CurItem = Undefined Then
				CurItem = DataTree.Rows.Add();
				CurItem.Object = ImportMode;
			Else
				CurItem = CurItem.Rows.Add();
				CurItem.Object = ImportMode;					
			EndIf;
			
		ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
			If CurItem = Undefined Then
				CurItem = Undefined;
			Else
				CurItem = CurItem.Parent;
			EndIf;
		ElsIf XMLReader.NodeType = XMLNodeType.Text Then
			CurItem.Value = XMLReader.Value;
		EndIf;
		
		For IndexOf = 0 To XMLReader.AttributeCount() - 1 Do
			String = CurItem.Rows.Add();
			String.Object = XMLReader.AttributeName(IndexOf);
			String.Value = XMLReader.AttributeValue(IndexOf);
		EndDo;
	EndDo;
	
	XMLReader.Close();
	
	Return DataTree;
EndFunction

Function ReadFormatsList(FormatsFile)
	
	XML = New XMLReader;
	XML.OpenFile(FormatsFile);
	FormatsDescription = New Map;
	
	While XML.Read() Do
		If XML.NodeType = XMLNodeType.StartElement AND XML.Name = "cellXfs" Then
			
			Position = 0;
			While XML.Read() Do
				If XML.NodeType = XMLNodeType.StartElement AND XML.Name = "xf" Then
					
					If XML.AttributeValue("numFmtId") <> Undefined Then 
						FormatsDescription.Insert(Position, "String"); // Take a 0 common format as a row
						FormatNumber =  Number(XML.AttributeValue("numFmtId"));
						If FormatNumber > 0 AND FormatNumber < 12 Then
							FormatsDescription[Position] = "Number";
						ElsIf FormatNumber > 13 AND FormatNumber <= 17 Then
							FormatsDescription[Position] = "Date";
						ElsIf FormatNumber >= 18 AND FormatNumber <= 21 Then
							FormatsDescription[Position] = "Time";
						ElsIf FormatNumber = 22 Then
							FormatsDescription[Position] = "DateTime";
						ElsIf FormatNumber >= 164 Then // Leave custom formats in a form of a text for now, but you need to see by the signs.
							FormatsDescription[Position] = "String";
						EndIf;
						
					EndIf;
					Position = Position + 1;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	XML.Close();
	Return FormatsDescription;
EndFunction

// Turns a row into a number without calling exceptions. Standard conversion function.
//   Number() strictly controls the absence of characters except for numeric characters.
//
Function RowToNumber(Val Value, DefaultValue = 0)
	
	Try
		If Value = Undefined OR Value ="0" Then
			
			// Process the presentation of a default value separately
			Result =DefaultValue;
			
		Else
			
			NumberPower = 0;
			Position = Find(Value, "E");
			If Position > 0 Then
				NumberPower = Mid(Value, Position + 1);
				Value = Left(Value, Position - 1);
			EndIf;
			
			TargetType = New TypeDescription("Number");
			Result = TargetType.AdjustValue(Value);
			
			If NumberPower <> 0 Then
				Result = Result * Pow(10, NumberPower);
			EndIf;
			
		EndIf;
		
	Except
		
		Result = Value;
		
	EndTry;
	
	Return Result;
	
EndFunction

#EndRegion

#Region WorkWithCSVFiles

Procedure ImportCSVFileToTable(FileName, TemplateWithData, InformationByColumns) Export
	
	File = New File(FileName);
	If Not File.Exist() Then 
		Return;
	EndIf;
	
	TextReader = New TextReader(FileName);
	String = TextReader.ReadLine();
	If String = Undefined Then 
		MessageText = NStr("en='Unable to import data from this file. Make sure that the data in the file is correct.';ru='Не получилось загрузить данные из этого файла. Убедитесь в корректности данных в файле.'");
		Return;
	EndIf;
	
	ColumnsHeaders = StringFunctionsClientServer.SplitStringIntoWordArray(String, ";");
	Source = New ValueTable;
	ColumnInFilePosition = New Map();
	
	Position = 1;
	For Each Column IN ColumnsHeaders Do
		
		FoundColumn = FindInformationAboutColumn(InformationByColumns, "Synonym", Column);
		If FoundColumn = Undefined Then
			FoundColumn = FindInformationAboutColumn(InformationByColumns, "ColumnPresentation", Column);
		EndIf;
		
		If FoundColumn <> Undefined Then
			NewColumn = Source.Columns.Add();
			NewColumn.Name = FoundColumn.ColumnName;
			NewColumn.Title = Column;
			ColumnInFilePosition.Insert(Position, NewColumn.Name);
			Position = Position + 1;
		EndIf;
	EndDo;
	
	If Source.Columns.Count() = 0 Then
		Return;
	EndIf;
	
	While String <> Undefined Do
		NewRow = Source.Add();
		Position = Find(String, ";");
		IndexOf = 0;
		While Position > 0 Do
			If Source.Columns.Count() < IndexOf + 1 Then
				Break;
			EndIf;
			ColumnName = ColumnInFilePosition.Get(IndexOf + 1);
			If ColumnName <> Undefined Then
				NewRow[ColumnName] = Left(String, Position - 1);
			EndIf;
			String = Mid(String, Position + 1);
			Position = Find(String, ";");
			IndexOf = IndexOf + 1;
		EndDo;
		If Source.Columns.Count() = IndexOf + 1  Then
			NewRow[IndexOf] = String;
		EndIf;

		String = TextReader.ReadLine();
	EndDo;
	
	FillTableByImportedDataFromFile(Source, TemplateWithData, InformationByColumns);
	
EndProcedure

Procedure SaveTableToCSVFile(PathToFile, InformationByColumns) Export
	
	TitleFormatForCSV = "";
	
	For Each Column IN InformationByColumns Do 
		TitleFormatForCSV = TitleFormatForCSV + Column.ColumnPresentation + ";";
	EndDo;
	
	If StrLen(TitleFormatForCSV) > 0 Then
		TitleFormatForCSV = Left(TitleFormatForCSV, StrLen(TitleFormatForCSV)-1);
	EndIf;
	
	File = New TextWriter(PathToFile);
	File.WriteLine(TitleFormatForCSV);
	File.Close();
	
EndProcedure

#EndRegion

#Region LongActions

Procedure WriteMatchedData(ExportParameters, StorageAddress) Export
	
	MatchedData = ExportParameters.MatchedData;
	CorrelationObjectName =ExportParameters.CorrelationObjectName;
	ImportParameters = ExportParameters.ImportParameters;
	InformationByColumns = ExportParameters.InformationByColumns;
	
	CreateIfNotMatched = ImportParameters.CreateIfNotMatched;
	UpdateExisting = ImportParameters.UpdateExisting;
	
	StringType = New TypeDescription("String");
	
	CatalogName = DecomposeFullObjectName(CorrelationObjectName).NameObject;
	ManagerOfCatalog = Catalogs[CatalogName];
	
	LineNumber = 0;
	TotalRows = MatchedData.Count();
	For Each TableRow IN MatchedData Do 
		LineNumber = LineNumber + 1;
		Try
			BeginTransaction();
			If Not ValueIsFilled(TableRow.MappingObject) Then 
				If CreateIfNotMatched Then 
					CatalogItem = ManagerOfCatalog.CreateItem();
					TableRow.MappingObject = CatalogItem;
					TableRow.RowMatchResult = "Created";
				Else
					TableRow.RowMatchResult = "Skipped";
					SetProgressPercent(TotalRows, LineNumber);
					Continue;
				EndIf;
			Else
				If Not UpdateExisting Then 
					TableRow.RowMatchResult = "Skipped";
					SetProgressPercent(TotalRows, LineNumber);
					Continue;
				EndIf;
				
				Block = New DataLock;
				LockItem = Block.Add("Catalog." + CatalogName);
				LockItem.SetValue("Ref", TableRow.MappingObject);
				
				CatalogItem = TableRow.MappingObject.GetObject();
				TableRow.RowMatchResult = "Updated";
				If CatalogItem = Undefined Then
					MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Products and services with %1 SKU do not exist.';ru='Номенклатура с артикулом %1 не существует.'"), TableRow.SKU);
					Raise MessageText;
				EndIf;
			EndIf;
			
			For Each Column IN InformationByColumns Do 
				If Column.Visible Then
					CatalogItem[Column.ColumnName] = TableRow[Column.ColumnName];
				EndIf;
			EndDo;
			
			If CatalogItem.CheckFilling() Then 
				CatalogItem.Write();
				CommitTransaction();
			Else
				TableRow.RowMatchResult = "Skipped";
				UserMessages = GetUserMessages(True);
				
				If UserMessages.Count() > 0 Then 
					MessagesText = "";
					For Each UserMessage IN UserMessages Do
						MessagesText = messagesText + UserMessage.Text + Chars.LF;
					EndDo;
					TableRow.ErrorDescription = MessagesText;
				EndIf;
			
				RollbackTransaction();

			EndIf;
			
			SetProgressPercent(TotalRows, LineNumber);
		Except
			RollbackTransaction();
			TableRow.RowMatchResult = "Skipped";
			TableRow.ErrorDescription = NStr("en='Unable to write as the data is incorrect.';ru='Невозможна запись из-за некорректности данных'");
		EndTry;
	
	EndDo;
	
	StorageAddress = PutToTempStorage(MatchedData, StorageAddress);
	
EndProcedure

Procedure SetProgressPercent(Total, LineNumber)
	Percent = LineNumber * 50 / Total;
	LongActionsModule = CommonUse.CommonModule("LongActions");
	LongActionsModule.TellProgress(Percent);
EndProcedure

Procedure FormReportAboutImportBackground(ExportParameters, StorageAddress) Export
	
	TableReport = ExportParameters.TableReport;
	MatchedData  = ExportParameters.MatchedData;
	InformationByColumns  = ExportParameters.InformationByColumns;
	TemplateWithData = ExportParameters.TemplateWithData;
	ReportType = ExportParameters.ReportType;
	CalculateProgressPercent = ExportParameters.CalculateProgressPercent;
	
	If Not ValueIsFilled(ReportType) Then
		ReportType = "AllItems";
	EndIf;
	
	GenerateReportTemplate(TableReport, TemplateWithData);
	
	TitleArea = TableTemplateTitleArea(TableReport);
	
	CreatedQuantity = 0;
	UpdatedQuantity = 0;
	SkippedQuantity = 0;
	SkippedQuantityWithError = 0;
	For LineNumber = 1 To MatchedData.Count() Do
		String = MatchedData.Get(LineNumber - 1);
		
		Cell = TableReport.GetArea(LineNumber + 1, 1, LineNumber + 1, 1);
		Cell.CurrentArea.Text = String.RowMatchResult;
		Cell.CurrentArea.Details = String.MappingObject;
		Cell.CurrentArea.Note.Text = String.ErrorDescription;
		If String.RowMatchResult = "Created" Then 
			Cell.CurrentArea.TextColor = StyleColors.ResultSuccessColor;
			CreatedQuantity = CreatedQuantity + 1;
		ElsIf String.RowMatchResult = "Updated" Then
			Cell.CurrentArea.TextColor = StyleColors.ExplanationText;
			UpdatedQuantity = UpdatedQuantity + 1;
		Else
			Cell.CurrentArea.TextColor = StyleColors.UnavailableCellTextColor;
			SkippedQuantity = SkippedQuantity + 1;
			If ValueIsFilled(String.ErrorDescription) Then
				SkippedQuantityWithError = SkippedQuantityWithError + 1;
			EndIf;
		EndIf;
		
		If ReportType = "AreNew" AND String.RowMatchResult <> "Created" Then
			Continue;
		EndIf;
		
		If ReportType = "Updated" AND String.RowMatchResult <> "Updated" Then 
			Continue;
		EndIf;
		
		If ReportType = "Skipped" AND String.RowMatchResult <> "Skipped" Then 
			Continue;
		EndIf;
		
		TableReport.Put(Cell);
		For IndexOf = 1 To InformationByColumns.Count() Do 
			Cell = TableReport.GetArea(LineNumber + 1, IndexOf + 1, LineNumber + 1, IndexOf + 1);
			
			Filter = New Structure("Position", IndexOf);
			FoundColumns = InformationByColumns.FindRows(Filter);
			If FoundColumns.Count() > 0 Then 
				ColumnName = FoundColumns[0].ColumnName;
				Cell.CurrentArea.Details = String.MappingObject;
				Cell.CurrentArea.Text = String[ColumnName];
				Cell.CurrentArea.TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
			EndIf;
			TableReport.Join(Cell);
			
		EndDo;
		
		If CalculateProgressPercent Then 
			Percent = Round(LineNumber * 50 / MatchedData.Count()) + 50;
			LongActionsModule = CommonUse.CommonModule("LongActions");
			LongActionsModule.TellProgress(Percent);
		EndIf;
		
	EndDo;
	
	Result = New Structure;
	Result.Insert("ReportType", ReportType);
	Result.Insert("Total", MatchedData.Count());
	Result.Insert("Created", CreatedQuantity);
	Result.Insert("Updated", UpdatedQuantity);
	Result.Insert("Skipped", SkippedQuantity);
	Result.Insert("Incorrect", SkippedQuantityWithError);
	Result.Insert("TableReport", TableReport);
	
	StorageAddress = PutToTempStorage(Result, StorageAddress); 
	
EndProcedure

Procedure GenerateReportTemplate(TableReport, TemplateWithData)
	
	TableReport.Clear();
	Cell = TemplateWithData.GetArea(1, 1, 1, 1);
	
	TableHeader = TemplateWithData.GetArea("R1");
	FillCellTemplateTitle(Cell, NStr("en='Result';ru='Результат'"), 12, NStr("en='Data load result';ru='Результат загрузки данных'"), True);
	TableReport.Join(TableHeader); 
	TableReport.InsertArea(Cell.CurrentArea, TableReport.Area("C1"), SpreadsheetDocumentShiftType.Horizontal);
	
	TableReport.FixedTop = 1;
EndProcedure

#EndRegion

//////////////////// Functional options ///////////////////////////////////////

// Returns columns depending on the functional options.
//
// Parameters:
//  FullObjectName - String - Object full name.
// Returns:
//   -  Map - 
Function ColumnsDependentOnFunctionalOptions(FullObjectName)
	
	ColumnsFunctionalOptions = ObjectsByOptionsAvailability(FullObjectName);
	AttributesList = Metadata.FindByFullName(FullObjectName).Attributes;
	
	InformationAboutFunctionalOptions = New Map;
	
	For Each Attribute IN AttributesList Do
		FunctionalOptionStatus = ColumnsFunctionalOptions.Get(Attribute);
		If FunctionalOptionStatus <> Undefined Then
				InformationAboutFunctionalOptions.Insert(Attribute.Name, FunctionalOptionStatus);
		EndIf;
	EndDo;
	
	Return InformationAboutFunctionalOptions;
	
EndFunction

// Availability of metadata objects by functional options.
//
Function ObjectsByOptionsAvailability(ObjectName) Export
	Parameters = CommonUseReUse.InterfaceOptions();
	If TypeOf(Parameters) = Type("FixedStructure") Then
		Parameters = New Structure(Parameters);
	EndIf;
	
	ObjectsAvailability = New Map;
	For Each FunctionalOption IN Metadata.FunctionalOptions Do
		
		For Each Item IN FunctionalOption.Content Do
			If Item.Object <> Undefined Then
				If Find(Item.Object.FullName(), ObjectName) > 0 Then
					Value = GetFunctionalOption(FunctionalOption.Name, Parameters);
					If Value = True Then
						ObjectsAvailability.Insert(Item.Object, True);
					Else
						If ObjectsAvailability[Item.Object] = Undefined Then
							ObjectsAvailability.Insert(Item.Object, False);
						EndIf;
					EndIf;
				EndIf;
			EndIf;
			
		EndDo;
	EndDo;
	Return ObjectsAvailability;
EndFunction


#EndRegion

#EndIf
