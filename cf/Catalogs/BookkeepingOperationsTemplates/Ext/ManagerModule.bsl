Function GetTableOfTables(DocumentBase = Undefined, OtherSynonym = Undefined) Export
	
	TableOfTables = GetTableStructureForSelectedTables();
	
	If DocumentBase<>Undefined Then
		
		MetadataObject = DocumentBase.Metadata();
		
		For Each MetadataObjectItem In MetadataObject.TabularSections Do
			
			NewRow = TableOfTables.Add();
			NewRow.TableName = MetadataObjectItem.Name;
			NewRow.TableKind = Enums.BookkeepingOperationTemplateTableKind.TabularSection;
			NewRow.TableSynonym = MetadataObjectItem.Synonym;
			NewRow.TablePicture = PictureLib.TabularSection;
			
		EndDo;	
		
		For Each MetadataObjectItem In MetadataObject.RegisterRecords Do
			
			MetadataType = Enums.BookkeepingOperationTemplateTableKind.DocumentRecords;
			
			If Metadata.InformationRegisters.Contains(MetadataObjectItem) Then
				
				If MetadataObjectItem.InformationRegisterPeriodicity = Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical then
					
					MetadataType = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterNonperiodic;
					
				Else
					
					MetadataType = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterPeriodic;
					
				EndIf;
				
				TablePicture = PictureLib.InformationRegister;
				
			ElsIf Metadata.AccumulationRegisters.Contains(MetadataObjectItem) Then
				
				MetadataType = Enums.BookkeepingOperationTemplateTableKind.AccumulationRegister;
				
				TablePicture = PictureLib.AccumulationRegister;
				
			EndIf;
			
			NewRow = TableOfTables.Add();
			NewRow.TableName = MetadataObjectItem.Name;
			NewRow.TableKind = MetadataType;
			NewRow.TableSynonym = MetadataObjectItem.Synonym;
			NewRow.TablePicture = TablePicture;
			
		EndDo;
		
	EndIf;

	NewRow = TableOfTables.Add();
	NewRow.TableName = "";
	NewRow.TableKind = Enums.BookkeepingOperationTemplateTableKind.DocumentRecords;
	If OtherSynonym = Undefined Then
		NewRow.TableSynonym = Nstr("en = 'Document''s data'; pl = 'Dane dokumentu'");		
	Else
		NewRow.TableSynonym = OtherSynonym;
	EndIf;	
	NewRow.TablePicture = PictureLib.RecordsByDocument;
	
	Return TableOfTables;
	
EndFunction

Function GetTableStructureForSelectedTables()
	
	TableStructureForSelectedTables = New ValueTable();
	
	TableStructureForSelectedTables.Columns.Add("TableName");
	TableStructureForSelectedTables.Columns.Add("TableSynonym");
	TableStructureForSelectedTables.Columns.Add("TableKind");
	TableStructureForSelectedTables.Columns.Add("TablePicture");
	TableStructureForSelectedTables.Columns.Add("Filter");
	
	Return TableStructureForSelectedTables;
	
EndFunction

// SelectedTables - table values from which will be excluded from available fields
// OtherSynonym - synonym for tabel with document's records
// TableKindFilter - Filter, which contains ValueList with available kinds. May be undefined
// TableNameFilter - Filter, which contains Name of table which should be selected. This filter is active only if TableKindFilter is not undefined. May be undefined
Function GetListOfAvailableTables(SelectedTables = Undefined, OtherSynonym = Undefined, TableKindFilter = Undefined, TableNameFilter = Undefined, DocumentBase = Undefined) Export
	
	TableOfTables = GetTableOfTables(DocumentBase, OtherSynonym);
	ListOfAvailableTables = GetTreeStructureForSelectedTables();
	
	UsedTablesTable = New ValueTable();
	UsedTablesTable.Columns.Add("TableName");
	UsedTablesTable.Columns.Add("TableKind");
	
	If SelectedTables<>Undefined Then
		GetUsedTablesTableFromSelectedTablesTree(SelectedTables.GetItems(),UsedTablesTable);	
	EndIf;
	
	TableOfTables.Sort("TableKind, TableSynonym");
	
	TabularSectionRows = Undefined;
	InformationRegisterRows = Undefined;
	AccumulationRegisterRows = Undefined;
	
	For Each Row In TableOfTables Do
		
		If IsCorrespondsToFilter(Row.TableName,Row.TableKind,TableKindFilter, TableNameFilter) Then
			
			ParentRows = GetParentRowsByKind(Row.TableKind,ListOfAvailableTables);
									
			NewRow = ParentRows.Rows.Add();
			NewRow.TableName = Row.TableName;
			NewRow.TableKind = Row.TableKind;
			NewRow.TableSynonym = Row.TableSynonym;
			NewRow.TablePicture = Row.TablePicture;
			NewRow.Availability = NOT IsTableWasUsedInSelectedTables(UsedTablesTable,Row.TableName,Row.TableKind);  		
			
		EndIf;	
		
	EndDo;	
	
	GetAvailabilityForAllChildRows(ListOfAvailableTables.Rows);
	
	Return ListOfAvailableTables;
	
EndFunction	

Function GetListOfNotAvailableTables(SelectedTablesRows, TableOfTables = Undefined, ListOfNotAvailableTables = Undefined, DocumentBase = Undefined) Export
	
	If TableOfTables = Undefined Then
		TableOfTables = GetTableOfTables(DocumentBase);
	EndIf;
	
	If ListOfNotAvailableTables = Undefined Then
		ListOfNotAvailableTables = New Array();
	EndIf;	

	For Each SelectedTablesRow In SelectedTablesRows Do
		
		If SelectedTablesRow.Rows.Count() > 0 Then
			GetListOfNotAvailableTables(SelectedTablesRow.Rows, TableOfTables, ListOfNotAvailableTables,DocumentBase);
		Else
			If SelectedTablesRow.Parent <> Undefined Then
				If TablesProcessingAtClientAtServer.FindTabularPartRow(TableOfTables, New Structure("TableName, TableKind", SelectedTablesRow.TableName, SelectedTablesRow.TableKind)) = Undefined Then
					ListOfNotAvailableTables.Add(SelectedTablesRow);
				EndIf;	
			EndIf;
		EndIf;	
		
	EndDo;	
	
	Return ListOfNotAvailableTables;
	
EndFunction

Function IsTableWasUsedInSelectedTables(UsedTablesTable,TableName,TableKind)
	
	FoundRows = UsedTablesTable.FindRows(New Structure("TableName, TableKind",TableName,TableKind));
	Return (FoundRows.Count()<>0);
	
EndFunction	

Function GetKindPicture(TableKind) Export
	
	If TableKind = Enums.BookkeepingOperationTemplateTableKind.TabularSection Then
		
		TablePicture = PictureLib.TabularSection;
		
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterNonperiodic
		OR TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterPeriodic Then
	
		TablePicture = PictureLib.InformationRegister;
		
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.AccumulationRegister Then	
		
		TablePicture = PictureLib.AccumulationRegister;
				
	Else
		
		TablePicture = PictureLib.RecordsByDocument;
		
	EndIf;

	Return  TablePicture;
	
EndFunction	

Function GetParentRowsByKind(TableKind, AllRecords) Export
	
	If TableKind = Enums.BookkeepingOperationTemplateTableKind.TabularSection Then
		
		TabularSectionRows = AllRecords.Rows.Find("AllTabularSections","TableName",False);
		
		If TabularSectionRows = Undefined Then
			
			TabularSectionRows = AllRecords.Rows.Add();
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
		
		InformationRegisterRows = AllRecords.Rows.Find("AllInformationRegisters","TableName",False);
		
		If InformationRegisterRows = Undefined Then
			
			InformationRegisterRows = AllRecords.Rows.Add();
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
		
		AccumulationRegisterRows = AllRecords.Rows.Find("AllAccumulationRegisters","TableName",False);
		
		If AccumulationRegisterRows = Undefined Then
			
			AccumulationRegisterRows = AllRecords.Rows.Add();
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

Procedure GetUsedTablesTableFromSelectedTablesTree(SelectedTablesTree,UsedTablesTable)
		
	If SelectedTablesTree<> Undefined Then
		
		For Each Row In SelectedTablesTree Do
			
			If Row.GetItems().Count() = 0 Then
				
				If Row.GetParent() <> Undefined Then
					
					NewRow = UsedTablesTable.Add();
					NewRow.TableName = Row.TableName;
					NewRow.TableKind = Row.TableKind;
					
				EndIf; 
				
			Else
								
				GetUsedTablesTableFromSelectedTablesTree(Row.GetItems(),UsedTablesTable);
				
			EndIf;	
			
		EndDo;	
		
	EndIf;
	
EndProcedure	

Function GetAvailabilityForAllChildRows(Rows)
	
	AtLeastOneRowAvailable = False;
	
	For Each Row In Rows Do
		
		If Row.Rows.Count()>0 Then
			Row.Availability = GetAvailabilityForAllChildRows(Row.Rows);
		EndIf;	
		
		If Row.Availability Then 
			AtLeastOneRowAvailable = True;
		EndIf;	
		
	EndDo;	
	
	Return AtLeastOneRowAvailable; 
	
EndFunction	

// Row - Structure which should contains 2 fields, TableName and TableKind
// TableKindFilter - Filter, which contains ValueList with available kinds. May be undefined
// TableNameFilter - Filter, which contains Name of table which should be selected. This filter is active only if TableKindFilter is not undefined. May be undefined.
Function IsCorrespondsToFilter(TableName, TableKind, TableKindFilter = Undefined, TableNameFilter = Undefined)
	
	CorrespondsToFilter = True;
	
	If TableKindFilter <> Undefined AND TableKindFilter.Count()>0 Then
		
		If TableKindFilter.FindByValue(TableKind)<> Undefined Then
			If TableNameFilter <> Undefined 
				AND TableKind <> Enums.BookkeepingOperationTemplateTableKind.DocumentRecords Then
				If TrimAll(Upper(TableNameFilter)) <> TrimAll(Upper(TableName)) Then
					CorrespondsToFilter = False;
				EndIf;	
			EndIf;	
		Else
			CorrespondsToFilter = False;
		EndIf;	
		
	EndIf;	
	
	Return CorrespondsToFilter;
	
EndFunction	

Function GetTreeStructureForSelectedTables()
	
	TableStructureForSelectedTables = New ValueTree();
	
	TableStructureForSelectedTables.Columns.Add("TableName");
	TableStructureForSelectedTables.Columns.Add("TableSynonym");
	TableStructureForSelectedTables.Columns.Add("TableKind");
	TableStructureForSelectedTables.Columns.Add("TablePicture");
	TableStructureForSelectedTables.Columns.Add("Filter");
	TableStructureForSelectedTables.Columns.Add("Availability");
	
	Return TableStructureForSelectedTables;
	
EndFunction	

Function ApplyDocumentBaseTableChange(DocumentBase, TableName,TableKind,DCSInTempStorage) Export
	
	MetadataObject = DocumentBase.Metadata();
	
	DCS = New DataCompositionSchema;
	
	DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
	
	DataSource = TemplateReports.AddLocalDataSource(DCS);
	
	DataSet = TemplateReports.AddDataSetQuery(DCS.DataSets, DataSource);
	AdditionalFields = Undefined;
	DataSet.Query = GenerateQueryByMetadata(DocumentBase, TableName,TableKind,AdditionalFields);
	
	MetadataAttributes = MetadataObject.Attributes;
	
	MetadataAttributesArray = New Array();
	
	If IsBlankString(TableName) Then
		NewField = TemplateReports.AddDataSetField(DCS.DataSets[0], "Ref", Nstr("en='Reference';pl='Odwołanie'"));
		NewField.AttributeUseRestriction.Field = True;
		TemplateReports.AddDataSetField(DCS.DataSets[0], "DeletionMark", Nstr("en='Deletion mark';pl='Zaznaczenie do usunięcia'"));
		TemplateReports.AddDataSetField(DCS.DataSets[0], "Date", Nstr("en='Date';pl='Data'"));
		If MetadataObject.Posting = Metadata.ObjectProperties.Posting.Allow Then
			TemplateReports.AddDataSetField(DCS.DataSets[0], "Posted", Nstr("en='Posted';pl='Zatwierdzony'"));
		EndIf;	
		If MetadataObject.NumberLength > 0 Then
			TemplateReports.AddDataSetField(DCS.DataSets[0], "Number", Nstr("en='Number';pl='Numer'"));
		EndIf;	
		MetadataAttributesArray.Add(MetadataAttributes);
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.TabularSection Then	
		NewField = TemplateReports.AddDataSetField(DCS.DataSets[0], "Ref", Nstr("en='Reference';pl='Odwołanie'"));
		NewField.UseRestriction.Field = True;
		NewField.AttributeUseRestriction.Field = True;
		MetadataAttributes = MetadataObject.TabularSections[TableName].Attributes;
		MetadataAttributesArray.Add(MetadataAttributes);
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.AccumulationRegister Then	
		MetadataObject = Metadata.AccumulationRegisters[TableName];
		MetadataAttributesArray.Add(MetadataObject.Attributes);
		MetadataAttributesArray.Add(MetadataObject.Dimensions);
		MetadataAttributesArray.Add(MetadataObject.Resources);
		TemplateReports.AddDataSetField(DCS.DataSets[0], "Recorder", Nstr("en='Recorder';pl='Rejestrator'"));
		TemplateReports.AddDataSetField(DCS.DataSets[0], "Period", Nstr("en='Period';pl='Okres'"));
		If MetadataObject.RegisterType = Metadata.ObjectProperties.AccumulationRegisterType.Balance Then
			TemplateReports.AddDataSetField(DCS.DataSets[0], "RecordType", Nstr("en='Record type';pl='Typ zapisu'"));
		EndIf;	
		
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterPeriodic 
		OR TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterNonperiodic Then	
		MetadataObject = Metadata.InformationRegisters[TableName];
		MetadataAttributesArray.Add(MetadataObject.Attributes);
		MetadataAttributesArray.Add(MetadataObject.Dimensions);
		MetadataAttributesArray.Add(MetadataObject.Resources);
		TemplateReports.AddDataSetField(DCS.DataSets[0], "Recorder", Nstr("en='Recorder';pl='Rejestrator'"));
		If MetadataObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
			TemplateReports.AddDataSetField(DCS.DataSets[0], "Period", Nstr("en='Period';pl='Okres'"));
		EndIf;	
	EndIf;	
	
	For Each MetadataAttributesSet In MetadataAttributesArray Do
		For each Attribute In MetadataAttributesSet Do
			AddedField = TemplateReports.AddDataSetField(DCS.DataSets[0], Attribute.Name, Attribute.Synonym);
		EndDo;
	EndDo;
	
	For each AdditionalField In AdditionalFields Do
		AddedField = TemplateReports.AddDataSetField(DCS.DataSets[0], AdditionalField.Name, AdditionalField.Title, AdditionalField.DataPath);
	EndDo;	
	
	NewParameter = DCS.Parameters.Add();
	NewParameter.Name = "Period";
	NewParameter.IncludeInAvailableFields = False;
	
	DCSInTempStorage = PutToTempStorage(DCS, New UUID());
	DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DCSInTempStorage));
	DataCompositionSettingsComposer.LoadSettings(DCS.DefaultSettings);	
	
	Return DataCompositionSettingsComposer;
	
EndFunction	

Function GenerateQueryByMetadata(DocumentBase, TableName, TableKind,AdditionalDataSetFields)
		
	AdditionalDataTable = GetTableOfObjectsWithAdditionalFields();
	
	IncludedRegistersQuery = "";
	IncludedRegistersAndFields = New ValueTable();
	IncludedRegistersAndFields.Columns.Add("TableAlias");
	IncludedRegistersAndFields.Columns.Add("FieldName");
	IncludedRegistersAndFields.Columns.Add("TableName");
	
	AdditionalDataSetFields = New ValueTable();
	AdditionalDataSetFields.Columns.Add("Name");
	AdditionalDataSetFields.Columns.Add("Title");
	AdditionalDataSetFields.Columns.Add("DataPath");
	
	MetadataObject = DocumentBase.Metadata();
	
	SelectedAttributes = "";
	
	MetadataAttributesArray = New Array();
	
	If IsBlankString(TableName) Then
		MetadataAttributes = MetadataObject.Attributes;
		// Predefined items for document
		SelectedAttributes = SelectedAttributes +  "DataSource.Ref, DataSource.DeletionMark, DataSource.Date, ";
		If MetadataObject.Posting = Metadata.ObjectProperties.Posting.Allow Then
			SelectedAttributes = SelectedAttributes +  "DataSource.Posted, ";
		EndIf;	
		If MetadataObject.NumberLength > 0 Then
			SelectedAttributes = SelectedAttributes +  "DataSource.Number, ";
		EndIf;	
		MetadataAttributesArray.Add(MetadataAttributes);
		TableKindName = "Document";
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.TabularSection Then
		SelectedAttributes = SelectedAttributes +  "DataSource.Ref, ";
		MetadataAttributes = MetadataObject.TabularSections[TableName].Attributes;
		MetadataAttributesArray.Add(MetadataAttributes);
		TableKindName = "Document";
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.AccumulationRegister Then	
		
		MetadataObject = Metadata.AccumulationRegisters[TableName];
		MetadataAttributesArray.Add(MetadataObject.Attributes);
		MetadataAttributesArray.Add(MetadataObject.Dimensions);
		MetadataAttributesArray.Add(MetadataObject.Resources);
		TableKindName = "AccumulationRegister";
		
		SelectedAttributes = SelectedAttributes +  "DataSource.Recorder, DataSource.Period, ";
		
		If MetadataObject.RegisterType = Metadata.ObjectProperties.AccumulationRegisterType.Balance Then
			SelectedAttributes = SelectedAttributes +  "DataSource.RecordType, ";
		EndIf;	
				
	ElsIf TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterPeriodic 
		OR TableKind = Enums.BookkeepingOperationTemplateTableKind.InformationRegisterNonperiodic Then	
		MetadataObject = Metadata.InformationRegisters[TableName];
		MetadataAttributesArray.Add(MetadataObject.Attributes);
		MetadataAttributesArray.Add(MetadataObject.Dimensions);
		MetadataAttributesArray.Add(MetadataObject.Resources);
		TableKindName = "InformationRegister";
		
		SelectedAttributes = SelectedAttributes +  "DataSource.Recorder, ";
		
		If MetadataObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
			SelectedAttributes = SelectedAttributes +  "DataSource.Period, ";
		EndIf;
		
	EndIf;	
	
	For Each MetadataAttributesSet In MetadataAttributesArray Do
		
		For each Attribute In MetadataAttributesSet Do
			
			SelectedAttributes = SelectedAttributes + "DataSource." + Attribute.Name + ", ";
			
			For Each AdditionalDataTableItem In AdditionalDataTable Do
				
				If Attribute.Type.ContainsType(TypeOf(AdditionalDataTableItem.Type)) Then
					
					InformationRegisterMetadata = Metadata.InformationRegisters[AdditionalDataTableItem.Register].Resources;
					
					LocalTableName = Attribute.Name + AdditionalDataTableItem.DataPath + AdditionalDataTableItem.Register;
					
					LocalAdditionalDataTableItemQuery = AdditionalDataTableItem.Query;
					LocalAdditionalDataTableItemQuery = StrReplace(LocalAdditionalDataTableItemQuery,"_OBJECT_","DataSource."+Attribute.Name);
					LocalAdditionalDataTableItemQuery = StrReplace(LocalAdditionalDataTableItemQuery,"_REGISTER_",LocalTableName);
					
					IncludedRegistersQuery = IncludedRegistersQuery + LocalAdditionalDataTableItemQuery;
					
					For Each InformationRegisterMetadataAttribute In InformationRegisterMetadata Do
						
						SelectedAttributes = SelectedAttributes + LocalTableName + "." + InformationRegisterMetadataAttribute.Name+" AS "+Attribute.Name + InformationRegisterMetadataAttribute.Name+", ";
						NewAdditionalDataSetField = AdditionalDataSetFields.Add();
						NewAdditionalDataSetField.Name = Attribute.Name + InformationRegisterMetadataAttribute.Name;
						NewAdditionalDataSetField.Title = Attribute.Synonym + "." +?(IsBlankString(AdditionalDataTableItem.DataPathSynonym),"",AdditionalDataTableItem.DataPathSynonym+".") + InformationRegisterMetadataAttribute.Synonym;
						NewAdditionalDataSetField.DataPath = Attribute.Name + "." + ?(IsBlankString(AdditionalDataTableItem.DataPath),"",AdditionalDataTableItem.DataPath+".")+ InformationRegisterMetadataAttribute.Name;
						
					EndDo;	
					
				EndIf;	
				
			EndDo;		
			
		EndDo;
		
	EndDo;
	
	SelectedAttributes = Left(SelectedAttributes,StrLen(SelectedAttributes)-2);
	
	
	QueryText = " SELECT ALLOWED " + Chars.LF;
	
	QueryText = QueryText + SelectedAttributes + 
	" FROM "+ TableKindName + "." + MetadataObject.Name;
	
	If Not IsBlankString(TableName) 
		AND (TableKind = Enums.BookkeepingOperationTemplateTableKind.TabularSection 
		OR TableKind = Enums.BookkeepingOperationTemplateTableKind.TabularSection) Then
		QueryText = QueryText + "." + TableName;
	EndIf;
	
	QueryText = QueryText + " AS DataSource" + IncludedRegistersQuery;
	
	Return QueryText;
	
EndFunction

Function GetTableOfObjectsWithAdditionalFields()
	
	AdditionalDataTable = New ValueTable;
	AdditionalDataTable.Columns.Add("Type");
	AdditionalDataTable.Columns.Add("DataPath");
	AdditionalDataTable.Columns.Add("Query");
	AdditionalDataTable.Columns.Add("Register");
	AdditionalDataTable.Columns.Add("DataPathSynonym");
		
	Template = GetTemplate("LinkToBookkeepingData");
	LinkToBookkeepingDataTemplateText = GetTemplate("LinkToBookkeepingDataTemplateText").GetText();
	LinkToBookkeepingDataTemplate = Common.GetObjectFromXML(LinkToBookkeepingDataTemplateText,Type("DataCompositionSchema"));
	
	XMLContenMap = AdditionalInformationRepository.GetContentMapFromXML(Template.GetText());
	LinkToBookkeepingData = XMLContenMap.Get("LinkToBookkeepingData");
	If LinkToBookkeepingData <> Undefined Then
		
		CatalogsLinks = LinkToBookkeepingData.Get("Catalogs");
		If CatalogsLinks <> Undefined Then
			
			For Each CatalogItem In CatalogsLinks Do
				
				CatalogItemData = CatalogItem.Value;
				If CatalogItemData = Undefined Then
					Continue;
				EndIf;	
				
				Try
					CatalogName = TrimAll(CatalogItemData.Get("Name"));
					CatalogType = Catalogs[CatalogName].EmptyRef();
					TypesArray = New ValueList();
					TypesArray.Add(TypeOf(CatalogType));
				Except
					Continue;
				EndTry;	
				
				Try
					RegisterName = TrimAll(CatalogItemData.Get("Register"));
					Register = InformationRegisters[RegisterName];
				Except
					Continue;
				EndTry;
				
				CatalogDataPath = CatalogItemData.Get("Datapath");
				DataPathSynonym = "";
				If CatalogDataPath <> Undefined 
					AND NOT IsBlankString(CatalogDataPath) Then
					BufCatalogDataPath = CatalogDataPath;
					FoundDot = Find(BufCatalogDataPath,".");
					While NOT IsBlankString(BufCatalogDataPath) Do
						If FoundDot = 0 Then
							CurrentPartOfPath = BufCatalogDataPath;
						Else	
							CurrentPartOfPath = Left(BufCatalogDataPath,FoundDot-1);
						EndIf;	
						NewTypesArray = New ValueList();
						CurrentSynonym = "";
						For Each TypeItem In TypesArray Do
							CurrentNewType = New (TypeItem.Value);
							CurrentMetadata = CurrentNewType.Metadata();	
							If CommonAtServer.IsDocumentAttribute(CurrentPartOfPath,CurrentMetadata) Then
								CurrentSynonym = CurrentMetadata.Attributes[CurrentPartOfPath].Synonym;
								For Each MetadataType In CurrentMetadata.Attributes[CurrentPartOfPath].Type.Types() Do
									If NewTypesArray.FindByValue(MetadataType) = Undefined Then
										NewTypesArray.Add(MetadataType);
									EndIf;	
								EndDo;	
							EndIf;	
						EndDo;
						If NOT IsBlankString(CurrentSynonym) Then
							DataPathSynonym = DataPathSynonym + ?(IsBlankString(DataPathSynonym),CurrentSynonym,"."+CurrentSynonym);
						EndIf;	
						BufCatalogDataPath = Right(BufCatalogDataPath,StrLen(BufCatalogDataPath)-FoundDot);
						FoundDot = Find(BufCatalogDataPath,".");
						If FoundDot = 0 Then 
							BufCatalogDataPath = "";
						EndIf;	
						TypesArray = NewTypesArray;
					EndDo;	
					
				EndIf;	

				QueryText = LinkToBookkeepingDataTemplate.DataSets[CatalogName].Query;
				LeftPos = Find(QueryText,"{");
				RightPos = Find(QueryText,"}");
				SelectedQueryText = Mid(QueryText,LeftPos,RightPos-LeftPos+1);
				
				NewRow = AdditionalDataTable.Add();
				NewRow.Type = CatalogType;
				
				NewRow.DataPath = TrimAll(?(CatalogDataPath=Undefined,"",CatalogDataPath));
				NewRow.DataPathSynonym = DataPathSynonym;
				NewRow.Query = SelectedQueryText;
				NewRow.Register = RegisterName;
				
			EndDo;	
			
		EndIf;	
		
	EndIf;	
			
	Return AdditionalDataTable;
	
EndFunction	

Function GetRecordPresentation() Export
	
	Return Nstr("en = 'Record'; pl = 'Zapis'");
	
EndFunction	

Function GetParameterNameByPresentation(ParameterPresentation, TableKind, TableName,RecordsTableBoxName = Undefined,Parameters) Export
	
	FoundDot = Find(ParameterPresentation,".");
	
	If FoundDot>1 Then
		MaybeRecord = Left(ParameterPresentation,FoundDot-1);
		RecordPresentation = GetRecordPresentation();
		FoundRecord = Find(MaybeRecord,RecordPresentation);
		If FoundRecord=1 Then
			NumberAsString = Mid(MaybeRecord,StrLen(RecordPresentation)+1);
			
			Try
			
				Number = Number(NumberAsString);
			
			Except
				
				Number = 0;
				
			EndTry; 
			
			If Number<>0 AND RecordsTableBoxName <> Undefined Then
				
				Field = Upper(TrimAll(Mid(ParameterPresentation,FoundDot+1)));
				//For Each Attribute In Metadata().TabularSections[RecordsTableBox.Data].Attributes Do				
				For Each Attribute In Metadata.Catalogs.BookkeepingOperationsTemplates.TabularSections[RecordsTableBoxName].Attributes Do
					
					If Field = Upper(TrimAll(Attribute.Synonym)) Then
						
						Return ""+Number +"." + Attribute.Name;
						
					EndIf;	
					
				EndDo;	
				
			EndIf;	
			
		EndIf;	
		
	EndIf;
	
	FoundRows = Parameters.FindRows(New Structure("Presentation",ParameterPresentation));
	
	AvailableRows = New Array;
	AvailableRowsByDocumentRecords = New Array;
	
	For Each FoundRow In FoundRows Do
		
		If FoundRow.TableKind = TableKind 
			AND Upper(TrimAll(FoundRow.TableName)) = Upper(TrimAll(TableName)) Then
			
			AvailableRows.Add(FoundRow);	
			
		ElsIf FoundRow.TableKind = Enums.BookkeepingOperationTemplateTableKind.DocumentRecords Then
			
			AvailableRowsByDocumentRecords.Add(FoundRow);	
			
		EndIf;	
		
	EndDo;	
	
	If AvailableRows.Count()=1 Then
		Return AvailableRows[0].Name;
	ElsIf AvailableRows.Count()>1 Then
		Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Too many parameters with name %P1 found!'; pl = 'Dużo parametrów o nazwie %P1 znaleziono!'"),New Structure("P1",ParameterPresentation)));
		Return Undefined;
	ElsIf AvailableRowsByDocumentRecords.Count()=1 Then
		Return AvailableRowsByDocumentRecords[0].Name;
	ElsIf AvailableRowsByDocumentRecords.Count()>1 Then	
		Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Too many parameters with name %P1 found!'; pl = 'Dużo parametrów o nazwie %P1 znaleziono!'"),New Structure("P1",ParameterPresentation)));
		Return Undefined;
	Else
		Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'No parameters with name %P1 found!'; pl = 'Parametrów o nazwie %P1 nie znaleziono!'"),New Structure("P1",ParameterPresentation)));
		Return Undefined;
	EndIf;	
	
EndFunction	

Function GetFormulaByFormulaPresentation(FormulaPresentation, TableKind, TableName,RecordsTableBoxName = Undefined,Parameters) Export
	
	Formula = "";
	FormulaPresentationSubstring = FormulaPresentation;
	FormulaToEval = "";
	While True Do
		
		FoundParameterStart = Find(FormulaPresentationSubstring,"[");
		If FoundParameterStart = 0 Then
			
			Formula = Formula + FormulaPresentationSubstring;
			FormulaToEval = FormulaToEval + FormulaPresentationSubstring;
			
			Try
			
				Res = Eval(FormulaToEval);
			
			Except
				
				Return "";
			
			EndTry; 
			
			Return Formula;
			
		Else	
			
			Formula = Formula + Left(FormulaPresentationSubstring,FoundParameterStart-1);
			FormulaToEval = FormulaToEval + Left(FormulaPresentationSubstring,FoundParameterStart-1);
			FormulaPresentationSubstring = Right(FormulaPresentationSubstring,StrLen(FormulaPresentationSubstring)-FoundParameterStart);
			FoundParameterEnd = Find(FormulaPresentationSubstring,"]");
			If FoundParameterEnd = 0 Then
				Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Not found '']'' for parameter %P1!'; pl = 'Oczekuje się '']'' dla parametru %P1!'"), New Structure("P1",FormulaPresentationSubstring)));
				Return "";
			Else
				ParameterPresentation = Left(FormulaPresentationSubstring,FoundParameterEnd-1);
				FormulaPresentationSubstring = Right(FormulaPresentationSubstring,StrLen(FormulaPresentationSubstring)-FoundParameterEnd);
				ParameterName = GetParameterNameByPresentation(ParameterPresentation,TableKind,TableName,RecordsTableBoxName,Parameters);
				If ParameterName = Undefined Then
					Return "";
				Else
					Formula = Formula + "["+ParameterName+"]";
					FormulaToEval = FormulaToEval + "(1)";
				EndIf;	
			EndIf;	
			
		EndIf;
		
	EndDo;	
	
EndFunction	

Function GetFormulaPresentation(FormulaStructure,RecordsTableBoxName = Undefined,Parameters=Undefined) Export	
	If FormulaStructure.FillingMethod = Enums.FieldFillingMethods.Parameter Then
		Return GetParameterPresentationByName(FormulaStructure.Value,RecordsTableBoxName,Parameters);
	ElsIf FormulaStructure.FillingMethod = Enums.FieldFillingMethods.Formula Then	
		Return GetFormulaPresentationByFormula(FormulaStructure.Value,RecordsTableBoxName,Parameters);
	ElsIf FormulaStructure.FillingMethod = Enums.FieldFillingMethods.ProgrammisticFormula Then
		If IsBlankString(TrimAll(FormulaStructure.Value)) Then
			Return "";
		Else	
			Return Nstr("en = 'Programmistic formula'; pl = 'Wzór programistyczny'");
		EndIf;	
	EndIf;	
	
EndFunction

Function GetParameterPresentationByName(ParameterName,RecordsTableBoxName = Undefined,Parameters) Export
	
	FoundDot = Find(ParameterName,".");
	If FoundDot>0 Then
		
		If RecordsTableBoxName = Undefined Then
			Return Undefined;
		EndIf;
		
		// Get presentation from metadata
		RecordNumber = Number(Left(ParameterName,FoundDot));
		RecordField = Mid(ParameterName,FoundDot+1);
		
		Try
		
			Presentation = Nstr("en = 'Record'; pl = 'Zapis'") + RecordNumber + "." + Metadata.Catalogs.BookkeepingOperationsTemplates.TabularSections[RecordsTableBoxName].Attributes[RecordField].Synonym;			
		
		Except
			
			Presentation = Undefined;
			
		EndTry; 
		
		Return Presentation;
		
	Else
		// get presentation from parameters
		FoundRow = TablesProcessingAtClientAtServer.FindTabularPartRow(Parameters,New Structure("Name",ParameterName));
		If FoundRow <> Undefined Then
			Return FoundRow.Presentation;
		Else
			Return Undefined;
		EndIf;	
		
	EndIf;
	
EndFunction	

Function GetFormulaPresentationByFormula(Formula,RecordsTableBoxName = Undefined,Parameters) Export
	
	FormulaPresentation = "";
	FormulaSubstring = Formula;
	While True Do
		
		FoundParameterStart = Find(FormulaSubstring,"[");
		If FoundParameterStart = 0 Then
			
			FormulaPresentation = FormulaPresentation + FormulaSubstring;
			Return FormulaPresentation;
			
		Else	
			
			FormulaPresentation = FormulaPresentation + Left(FormulaSubstring,FoundParameterStart-1);
			FormulaSubstring = Right(FormulaSubstring,StrLen(FormulaSubstring)-FoundParameterStart);
			FoundParameterEnd = Find(FormulaSubstring,"]");
			If FoundParameterEnd = 0 Then
				Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Not found '']'' for parameter %P1!'; pl = 'Oczekuje się '']'' dla parametru %P1!'"), New Structure("P1",FormulaSubstring)));
				Return "";
			Else
				ParameterName = Left(FormulaSubstring,FoundParameterEnd-1);
				FormulaSubstring = Right(FormulaSubstring,StrLen(FormulaSubstring)-FoundParameterEnd);
				FormulaPresentation = FormulaPresentation + "["+GetParameterPresentationByName(ParameterName,RecordsTableBoxName,Parameters)+"]";
			EndIf;	
			
		EndIf;
		
	EndDo;	
	
EndFunction	

//  Returns parameters array corresponding with given type description
//
// Parameters:
//  TypeDescription   - TypeDescription Object
//
// Return Value:
//  Parameters array corresponding with given type description
Function GetParametersArray(TypeDescription, Parameters) Export

	ParametersArray = New Array;

	If TypeDescription = Undefined Then
		Return ParametersArray
	EndIf;
	For each Param In Parameters Do
		ParameterTypeDescription = ValueFromStringInternal(Param.TypeStringInternal);
		For each T In TypeDescription.Types() Do
			If not ValueIsNotFilled(ParameterTypeDescription) Then
				If ParameterTypeDescription.ContainsType(T) Then
					ParametersArray.Add(Param.Name);
					Break;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	Return ParametersArray;
EndFunction

// Returns parameters array corresponding with given type description
//
// Parameters:
//  TypeDescription   - TypeDescription Object
//
// Return Value:
//  Parameters value list corresponding with given type description
// 
Function GetParametersValueList(TypeDescription, TableKind, TableName, Parameters) Export

	ParametersValueList = New ValueList;
	
	For each Param In Parameters Do

		
		If Param.ParameterKind = Enums.BookkeepingOperationTemplateParameterKinds.LinkedToDocumentBase 
			AND Param.TableKind <> Enums.BookkeepingOperationTemplateTableKind.DocumentRecords Then
			
			If Param.TableKind <> TableKind OR Upper(TrimAll(Param.TableName))<>Upper(TrimAll(TableName)) Then
				Continue;
			EndIf;	
			
		EndIf;	
		
		If TypeDescription = Undefined Then
			ParametersValueList.Add(Param.Name,Param.Presentation);
		Else	
			ParameterTypeDescription = ValueFromStringInternal(Param.TypeStringInternal);
			For each T In TypeDescription.Types() Do
				
				If not ValueIsNotFilled(ParameterTypeDescription) Then
					If ParameterTypeDescription.ContainsType(T) Then
						ParametersValueList.Add(Param.Name,Param.Presentation);
						Break;
					EndIf;
				EndIf;
				
			EndDo;
		EndIf;

	EndDo;

	Return ParametersValueList;

EndFunction

Procedure FillParametersTree(ThisForm, ParametersTree, CurrentTableKind, CurrentTableName, CurrentFilterByType=False, CurrentTypeRestriction=Undefined, TableBoxName=Undefined, ShowNames = False, TableBoxCurrentIndexOfRecord = 0, TableBoxCurrentColumn="") Export
	ThisObject = ThisForm.Object;
	Parameters = ThisForm.Object.Parameters.Unload();	
	ObjectMetadata = ThisObject.Ref.Metadata();

	ParametersTree.Rows.Clear();
	
	If CurrentTableKind = Enums.BookkeepingOperationTemplateTableKind.DocumentRecords 
		AND TableBoxName <> Undefined AND ThisObject[TableBoxName].Count()>0 Then
		ParametersRow = ParametersTree.Rows.Add();
		ParametersRow.ParameterPresentation = Nstr("en='Parameters';pl='Parametry';");
	Else
		ParametersRow = ParametersTree;
	EndIf;
	
	ParametersValueList = GetParametersValueList(?(CurrentFilterByType,CurrentTypeRestriction,Undefined),CurrentTableKind,CurrentTableName,Parameters);	
	For each Param In ParametersValueList Do
		Row = ParametersRow.Rows.Add();
		Row.ParameterPresentation = Param.Presentation + ?(ShowNames," ("+Param.Value+")","");
		Row.ParameterName  = Param.Value;
	EndDo;
	
	If CurrentTableKind = Enums.BookkeepingOperationTemplateTableKind.DocumentRecords
		AND TableBoxName <> Undefined Then
		
		If ParametersRow.Rows.Count() = 0 Then
			ParametersTree.Rows.Delete(0);
		EndIf;
		For each TableRow In ThisObject[TableBoxName] Do
			
			IndexOfRecord = ThisObject[TableBoxName].Indexof(TableRow);
			RecordNumber  = IndexOfRecord+1;
			If IndexOfRecord > TableBoxCurrentIndexOfRecord Then
				// skip all records after this
				Return;
			EndIf;
			
			RecordsRow = ParametersTree.Rows.Add();
			RecordsRow.ParameterName = RecordNumber;
			RecordsRow.ParameterPresentation = GetRecordPresentation()+RecordNumber + ?(ShowNames," (Records["+IndexOfRecord+"])","");
			
			For each MDAttribute In Metadata.Catalogs.BookkeepingOperationsTemplates.TabularSections[TableBoxName].Attributes Do
				MDColumnName = MDAttribute.Name;
				If MDColumnName = "Formulas" 
					OR MDColumnName = "Condition" 
					OR MDColumnName = "TableName" 
					OR MDColumnName = "TableKind" 
					OR (IndexOfRecord = TableBoxCurrentIndexOfRecord
					AND MDColumnName = TableBoxCurrentColumn)Then
					Continue
				EndIf;
								
				ExtDimensionDescription = "";
				FieldTypes = Undefined;
				If Find(MDColumnName, "ExtDimension") > 0 Then
					Account = TableRow.Account;
					ExtDimensionNumber = Number(StrReplace(MDColumnName, "ExtDimension", ""));
					If Account.Isempty() Then
						FieldTypes = Metadata.ChartsOfCharacteristicTypes.BookkeepingExtDimensions.Type;
					ElsIf ExtDimensionNumber <= Account.ExtDimensionTypes.Count() Then
						ExtDimKind = Account.ExtDimensionTypes[ExtDimensionNumber-1].ExtDimensionType;
						ColumnTypesDescription = ExtDimKind.ValueType;
						FieldTypes = StrReplace(ExtDimKind.Description, " ", "_");
					EndIf;
				ElsIf Find(MDColumnName, "Quantity") > 0 Then
					Account = TableRow.Account;
					If Account.Isempty() Or Account.Quantity Then
						FieldTypes = ObjectMetadata.TabularSections[TableBoxName].Attributes[MDColumnName].Type;
					EndIf;
				ElsIf (Find(MDColumnName, "Currency") > 0) Or (Find(MDColumnName, "CurrencyAmount") > 0) Or (Find(MDColumnName, "ExchangeRate") > 0) Then
					Account = TableRow.Account;
					If Account.Isempty() Or Account.Currency Then
						ColumnTypesDescription = ObjectMetadata.TabularSections[TableBoxName].Attributes[MDColumnName].Type;
					EndIf;						
				Else						
					ColumnTypesDescription = ObjectMetadata.TabularSections[TableBoxName].Attributes[MDColumnName].Type;						
				EndIf;
				
				TempFlag = True;
				If CurrentFilterByType Then
					TempFlag = False;
					If FieldTypes = Undefined Then
						Continue
					EndIf;
					For each T In FieldTypes.Types() Do
						If CurrentTypeRestriction.ContainsType(T) Then
							TempFlag = True;
							Break;
						EndIf;
					EndDo;
				EndIf;
				
				If Not TempFlag Then
					Continue
				EndIf;
				
				RecordField = RecordsRow.Rows.Add();
				RecordField.ParameterPresentation = MDAttribute.Synonym + ?((ExtDimensionDescription <> "") AND (ExtDimensionDescription <> MDColumnName), " (", "") + ExtDimensionDescription + ?((ExtDimensionDescription <> "") AND (ExtDimensionDescription<>MDColumnName), ")", "") + ?(ShowNames," ("+MDColumnName+")","");
				RecordField.ParameterName  = "" + RecordNumber + "." + MDColumnName;
				
			EndDo;
			
			If RecordsRow.Rows.Count() = 0 Then
				ParametersTree.Rows.Delete(ParametersTree.Rows.Count()-1);
			EndIf;			
		EndDo;		
	EndIf;
EndProcedure // FillParametersTree()


// Find types, which are owners of given as Typedescription
//
// Parameters:
//  TypeDescription  - TypeDescription object
//
// Return Value:
//  TypeDescription object, contains types of possible object's owners 
Function GetPossibleOwnersTypes(TypeDescription) Export

	Types = New TypeDescription();

	For each MDObject In Metadata.Catalogs Do

		If MDObject.Owners.Count()=0 Then                		
			Continue
		EndIf;

		If TypeDescription.ContainsType(TypeOf(Catalogs[MDObject.Name].EmptyRef())) Then
			Types = New TypeDescription(TypeDescription, MetadataCollectionTypesArray(MDObject.Owners));
		EndIf;

	EndDo;

	Return Types;

EndFunction

// Parses metadata objects collection and adds corresponding refs types to array
//
// Parameters:
//  MDCollection    - metadata objects collection
//
// Return Value:
//  Metadata collection types array
// 
Function MetadataCollectionTypesArray(MDCollection)

	TypesArray = New Array;

	For each MDObject In MDCollection Do

		Try
			TypesArray.Add(TypeOf(Catalogs[MDObject.Name].EmptyRef()));
		Except
			TypesArray.Add(TypeOf(ChartsOfCharacteristicTypes[MDObject.Name].EmptyRef()));
		EndTry;

	EndDo;

	Return TypesArray;

EndFunction

