Function GetArrayRowsTable(Source, TableName, StructureAttributes) Export
	ArrayRows = New Array;
	For Each RowTable In Source[TableName] Do
		RowStructure = New Structure;
		For Each StructureAttribut In StructureAttributes Do
			AttributValuePathData = ?(StructureAttribut.Value = Undefined, StructureAttribut.Key, StructureAttribut.Value);
			AttributValue = RowTable;
			While Find(AttributValuePathData, ".") > 0 Do
				AttributValue = AttributValue[Left(AttributValuePathData, Find(AttributValuePathData, ".")-1)];
				AttributValuePathData = Right(AttributValuePathData, StrLen(AttributValuePathData) - Find(AttributValuePathData, "."));
			EndDo;
			AttributValue = AttributValue[AttributValuePathData];
			RowStructure.Insert(StructureAttribut.Key, AttributValue);
		EndDo;
		ArrayRows.Add(RowStructure);
	EndDo;
	
	Return ArrayRows;
EndFunction

Function GetLoadingDataFromSpreadsheetAvailableColumnsTable(Val ObjectRef, Val TabularSectionName, Val ColumnsStructure) Export
	
	AvailableColumnsTable = New ValueTable;
	AvailableColumnsTable.Columns.Add("Name",CommonAtClientAtServer.GetStringTypeDescription(100));
	AvailableColumnsTable.Columns.Add("Title",CommonAtClientAtServer.GetStringTypeDescription(100));
	AvailableColumnsTable.Columns.Add("Use",CommonAtClientAtServer.GetBooleanTypeDescription());
	AvailableColumnsTable.Columns.Add("ValueType");
	AvailableColumnsTable.Columns.Add("AvailableSearch");
	AvailableColumnsTable.Columns.Add("AvailableSearchPresentation",CommonAtClientAtServer.GetStringTypeDescription(0));
	
	RefMetadata = ObjectRef.Metadata();
	
	TabularSectionAttributes = RefMetadata.TabularSections[TabularSectionName].Attributes;
	
	TabularPartValueTable = New ValueTable;
	
	If ColumnsStructure = Undefined Then
		// columns order from metadata	
		For Each Attribute In TabularSectionAttributes Do
			
			AddLoadingDataFromSpreadsheetAvailableColumnsTableRow(AvailableColumnsTable, Attribute.Name, Attribute.Synonym, Attribute.Type);
						
		EndDo;
		
	Else
		// order from structure
		For Each StructureItem In ColumnsStructure Do
			
			Try
				Attribute = TabularSectionAttributes[StructureItem.Key];
			Except
				Attribute = Undefined
			EndTry;	
			
			StructureItemType = Undefined;
			If ColumnsStructure <> Undefined Then
				ColumnsStructure.Property(StructureItem.Key, StructureItemType);
			EndIf;	
			
			If Attribute = Undefined Then
				AddLoadingDataFromSpreadsheetAvailableColumnsTableRow(AvailableColumnsTable, StructureItem.Key, ?(TypeOf(StructureItem.Value) = Type("TypeDescription"), StructureItem.Key, StructureItem.Value), StructureItemType);
			Else
				AddLoadingDataFromSpreadsheetAvailableColumnsTableRow(AvailableColumnsTable, Attribute.Name, Attribute.Synonym, ?(StructureItemType = Undefined,Attribute.Type,StructureItemType));
			EndIf;
			
		EndDo;	
		
	EndIf;
	
	For Each AvailableColumnsTableRow In AvailableColumnsTable Do
		
		AvailableSearchTable = New ValueTree;
		AvailableSearchTable.Columns.Add("AvailableType");
		AvailableSearchTable.Columns.Add("MetadataFullName",CommonAtClientAtServer.GetStringTypeDescription(0));
		AvailableSearchTable.Columns.Add("MetadataPresentation",CommonAtClientAtServer.GetStringTypeDescription(0));
		AvailableSearchTable.Columns.Add("FieldName",CommonAtClientAtServer.GetStringTypeDescription(0));
		AvailableSearchTable.Columns.Add("FieldPresentation",CommonAtClientAtServer.GetStringTypeDescription(0));
		AvailableSearchTable.Columns.Add("Use",CommonAtClientAtServer.GetBooleanTypeDescription());
		// only for upper level
		AvailableSearchTable.Columns.Add("IsPrimitiveType",CommonAtClientAtServer.GetBooleanTypeDescription());
		// only for down level
		AvailableSearchTable.Columns.Add("IsAdditionalSet",CommonAtClientAtServer.GetBooleanTypeDescription());
		AvailableSearchTable.Columns.Add("AdditionalKeyName",CommonAtClientAtServer.GetStringTypeDescription(0));
		AvailableSearchTable.Columns.Add("PictureIndex");

		AvailableSearchPresentation = "";
		
		For Each AvailableType In AvailableColumnsTableRow.ValueType.Types() Do
			
			MetadataType = Metadata.FindByType(AvailableType);
			AvailableSearchTableRow = AvailableSearchTable.Rows.Add();
			TArray = New Array;
			TArray.Add(AvailableType);
			AvailableSearchTableRow.AvailableType = New TypeDescription(TArray);
			AvailableSearchTableRow.Use = True;
			
			If MetadataType = Undefined Then
				
				// primitive type
				AvailableSearchTableRow.MetadataPresentation = String(AvailableType);
				AvailableSearchTableRow.IsPrimitiveType = True;
				AvailableSearchTableRow.FieldPresentation = AvailableSearchTableRow.MetadataPresentation;
				
			ElsIf Metadata.Enums.Contains(MetadataType) Then
				
				// enum is also "primitive type" because can't be searched the same as other "any ref"
				AvailableSearchTableRow.MetadataFullName = MetadataType.FullName();
				AvailableSearchTableRow.MetadataPresentation = String(AvailableType); //MetadataType.ObjectPresentation;
				AvailableSearchTableRow.IsPrimitiveType = True;
				AvailableSearchTableRow.FieldPresentation = AvailableSearchTableRow.MetadataPresentation;
				AvailableSearchTableRow.PictureIndex = -1;
				
			Else	
				
				
				AvailableSearchTableRow.MetadataFullName = MetadataType.FullName();
				AvailableSearchTableRow.MetadataPresentation = MetadataType.ObjectPresentation;
				AvailableSearchTableRow.IsPrimitiveType = False;
				
				FieldsPresentation = "";

				For Each InputByStringItem In MetadataType.InputByString Do
					
					FoundAttribute = MetadataType.Attributes.Find(InputByStringItem.Name);
					If FoundAttribute = Undefined Then
						FoundAttribute = MetadataType.StandardAttributes[InputByStringItem.Name];
					EndIf;	
					
					Cancel = False;
					TypesArray = FoundAttribute.Type.Types();
					
					If TypesArray.Count()>1 Then
						Cancel = True;
					Else	
						For Each FoundType In TypesArray Do
							
							If Metadata.FindByType(FoundType) <> Undefined Then
								// not primitive type...need to skip
								Cancel = True;
								Break;
							EndIf;	
							
						EndDo;
					EndIf;
					
					If NOT Cancel Then
						
						AvailableSearchTableFieldRow = AvailableSearchTableRow.Rows.Add();
						AvailableSearchTableFieldRow.MetadataFullName = MetadataType.FullName();
						AvailableSearchTableFieldRow.MetadataPresentation = MetadataType.ObjectPresentation;
						AvailableSearchTableFieldRow.FieldName = InputByStringItem;
						AvailableSearchTableFieldRow.FieldPresentation = FoundAttribute.Presentation();
						AvailableSearchTableFieldRow.Use = True;
						AvailableSearchTableFieldRow.IsPrimitiveType = False;
						AvailableSearchTableFieldRow.PictureIndex = ObjectsExtensionsAtServer.GetMetadataClassPictureIndex(AvailableSearchTableFieldRow.MetadataFullName);
						
						FieldsPresentation = FieldsPresentation + AvailableSearchTableFieldRow.FieldPresentation + ", ";
						
					EndIf;	
					
				EndDo;	
				
				// only catalogs additional fields supported. may be extended
				If Metadata.Catalogs.Contains(MetadataType) AND MetadataType.Templates.Find("LoadingFromSpreadsheetAdditionalFields")<> Undefined Then
					
					LoadingFromSpreadsheetAdditionalFieldsTemplate = Catalogs[MetadataType.Name].GetTemplate("LoadingFromSpreadsheetAdditionalFields");
					ContentMap = AdditionalInformationRepository.GetContentMapFromXML(LoadingFromSpreadsheetAdditionalFieldsTemplate.GetText());
					AdditionalFieldsMap = ContentMap.Get("AdditionalFields");
					For Each KeyAndValue In AdditionalFieldsMap Do
						
						AdditionalFieldMap = KeyAndValue.Value;
						MetadataFullName = AdditionalFieldMap.Get("MetadataFullName");
						KeyMetadataFullName = AdditionalFieldMap.Get("Key");
						FieldMetadataFullName = AdditionalFieldMap.Get("Field");
						AdditionalFieldMetadata = Metadata.FindByFullName(MetadataFullName);
						KeyMetadata = Metadata.FindByFullName(KeyMetadataFullName);
						FieldMetadata = Metadata.FindByFullName(FieldMetadataFullName);
						
						AvailableSearchTableFieldRow = AvailableSearchTableRow.Rows.Add();
						AvailableSearchTableFieldRow.MetadataFullName = MetadataFullName;
						AvailableSearchTableFieldRow.MetadataPresentation = AdditionalFieldMetadata.Presentation();
						AvailableSearchTableFieldRow.FieldName = FieldMetadata.Name;
						AvailableSearchTableFieldRow.FieldPresentation = FieldMetadata.Presentation();
						AvailableSearchTableFieldRow.Use = True;
						AvailableSearchTableFieldRow.IsPrimitiveType = False;
						AvailableSearchTableFieldRow.PictureIndex = ObjectsExtensionsAtServer.GetMetadataClassPictureIndex(MetadataFullName);
						AvailableSearchTableFieldRow.IsAdditionalSet = True;
						AvailableSearchTableFieldRow.AdditionalKeyName = KeyMetadata.Name;
						
						FieldsPresentation = FieldsPresentation + AvailableSearchTableFieldRow.FieldPresentation + ", ";

						
					EndDo;	
					
				EndIf;	
				
				If IsBlankString(FieldsPresentation) Then
					// there is no fields. need to remove type
					AvailableSearchTable.Rows.Delete(AvailableSearchTableFieldRow);
					
				Else
					
					FieldsPresentation = Left(FieldsPresentation,StrLen(FieldsPresentation)-2);
					AvailableSearchTableRow.FieldPresentation =  FieldsPresentation;
					
				EndIf;
				
			EndIf;
			
			AvailableSearchPresentation = AvailableSearchPresentation + ?(AvailableSearchTableRow.IsPrimitiveType,AvailableSearchTableRow.MetadataPresentation,AvailableSearchTableRow.MetadataPresentation + ": " +AvailableSearchTableRow.FieldPresentation) + "; ";
			
		EndDo;	
			
		AvailableColumnsTableRow.Use = True;	
		AvailableColumnsTableRow.AvailableSearch = AvailableSearchTable;
		AvailableColumnsTableRow.AvailableSearchPresentation = Left(AvailableSearchPresentation, StrLen(AvailableSearchPresentation)-2);
		
	EndDo;	
	
	Return AvailableColumnsTable;
	
EndFunction	

Procedure AddLoadingDataFromSpreadsheetAvailableColumnsTableRow(AvailableColumnsTable, Val Name, Val Title, Val ValueType)
	
	AvailableColumnRow = AvailableColumnsTable.Add();
	AvailableColumnRow.Name = Name;
	AvailableColumnRow.Title = Title;
	AvailableColumnRow.ValueType = ValueType;
	
EndProcedure	

Function FillTabularSectionOnLoadingFromSpreadsheetResult(ObjectAddress, LoadingFromSpreadsheetResult, GroupingColumns = "", TotalingColumns = "") Export
	If TypeOf(ObjectAddress) = Type("String") Then
		Object = GetFromTempStorage(ObjectAddress);
	Else
		Object = ObjectAddress;
	EndIf;
	TabularSection = Object[LoadingFromSpreadsheetResult.TabularSectionName];
	
	If LoadingFromSpreadsheetResult.Overwrite Then
		TabularSection.Clear();
	EndIf;	
	
	AddedRowsArray = New Array();

	TablesStructure = GetFromTempStorage(LoadingFromSpreadsheetResult.TempStorageAddress);
	If TablesStructure = Undefined Then
		Return  New Array;
	EndIf;
	
	For Each SuccessTableRow In TablesStructure.SuccessTable Do
		
		NewTabularSectionRow = TabularSection.Add();
		AddedRowsArray.Add(TabularSection.IndexOf(NewTabularSectionRow));
		
		For Each SuccessTableColumn In TablesStructure.SuccessTable.Columns Do
			
			Try
				NewTabularSectionRow[SuccessTableColumn.Name] = SuccessTableRow[SuccessTableColumn.Name];
			Except
			EndTry;
			
		EndDo;	
		
	EndDo;	
	
	If Not IsBlankString(GroupingColumns) 
		AND Not IsBlankString(TotalingColumns) Then
		
		TabularSection.GroupBy(GroupingColumns,TotalingColumns);
		
	EndIf;	
	
	If TypeOf(ObjectAddress) = Type("String") Then
		PutToTempStorage(Object,ObjectAddress);
	EndIf;
	Return AddedRowsArray;
	
EndFunction	
