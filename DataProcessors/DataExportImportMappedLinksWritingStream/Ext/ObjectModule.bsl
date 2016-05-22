#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalState

Var CurrentContainer;
Var CurrentColumnNameWithSourceRef;
Var CurrentRefs;
Var CurrentSerializer;
Var CurrentMetadataObject;
Var PreviousRefs;
Var PreviousMetadataObject;

#EndRegion

#Region ServiceProgramInterface

Procedure Initialize(Container, Serializer) Export
	
	CurrentContainer = Container;
	CurrentSerializer = Serializer;
	
	CurrentColumnNameWithSourceRef = SourceDataColumnNewName();
	
EndProcedure

Procedure MatchRefOnImport(Val Refs, Val NaturalKey) Export
	
	If Refs.Metadata() <> PreviousMetadataObject Then
		OnChangeMetadataObject(Refs.Metadata());
	EndIf;
	
	If Refs = PreviousRefs Then
		
		MappingRefs = CurrentRefs.Find(Refs, CurrentColumnNameWithSourceRef);
		
	Else
		
		If CurrentRefs.Count() > LinksLimitInFile() Then
			WriteMatchedRefs();
		EndIf;
		
		MappingRefs = CurrentRefs.Add();
		
	EndIf;
	
	MappingRefs[CurrentColumnNameWithSourceRef] = Refs;
	For Each KeyAndValue IN NaturalKey Do
		
		If CurrentRefs.Columns.Find(KeyAndValue.Key) = Undefined Then
			
			TypeArray = New Array();
			TypeArray.Add(TypeOf(KeyAndValue.Value));
			TypeDescription = New TypeDescription(TypeArray, , New StringQualifiers(1024));
			
			CurrentRefs.Columns.Add(KeyAndValue.Key, TypeDescription);
			
		EndIf;
		
		MappingRefs[KeyAndValue.Key] = KeyAndValue.Value;
		
	EndDo;
	
	PreviousRefs = Refs;
	
EndProcedure

Procedure Close() Export
	
	WriteMatchedRefs();
	WriteSourceRefsColumnName();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure OnChangeMetadataObject(Val NewMetadataObject)
	
	If CurrentMetadataObject <> Undefined Then
		WriteMatchedRefs();
	EndIf;
	
	PreviousMetadataObject = CurrentMetadataObject;
	CurrentMetadataObject = NewMetadataObject;
	
	FillSourceRefsTableColumns();
	
	PreviousRefs = Undefined;
	
EndProcedure

Procedure FillSourceRefsTableColumns()
	
	CurrentRefs = New ValueTable();
	CurrentRefs.Columns.Add(CurrentColumnNameWithSourceRef, CommonUseSTLReUse.ReferenceTypeDescription());
	
	CommonDataTypes = DataExportImportServiceEvents.GetCommonDataTypesSupportMatchingRefsOnImport();
	If CommonDataTypes.Find(CurrentMetadataObject) <> Undefined Then
		NaturalKeyFields = ServiceTechnologyIntegrationWithSSL.ObjectManagerByFullName(CurrentMetadataObject.FullName()).NaturalKeyFields();
		For Each NaturalKeyField IN NaturalKeyFields Do
			FieldTypeDescription = AnObjectsDescriptionFieldTypes(CurrentMetadataObject, NaturalKeyField);
			OnlyRefTypes = True;
			For Each PossibleType IN FieldTypeDescription.Types() Do
				If CommonUseSTL.IsPrimitiveType(PossibleType) OR PossibleType = Type("ValueStorage") Then
					OnlyRefTypes = False;
					Break;
				EndIf;
			EndDo;
			If OnlyRefTypes Then
				FieldTypeDescription = CommonUseSTLReUse.ReferenceTypeDescription();
			EndIf;
			CurrentRefs.Columns.Add(NaturalKeyField, FieldTypeDescription);
		EndDo;
	EndIf;
	
	CurrentRefs.Indexes.Add(CurrentColumnNameWithSourceRef);
	
EndProcedure

// Returns TypeDescription for the metadata object attribute.
//
// Parameters:
// MetadataObject - Metadata object.
// FieldName - String attribute name.
//
// Returns:
// TypeDescription - description of the attribute types.
//
Function AnObjectsDescriptionFieldTypes(MetadataObject, FieldName)
	
	// Check for standard attributes
	For Each StandardAttribute IN MetadataObject.StandardAttributes Do 
		
		If StandardAttribute.Name = FieldName Then 
			 Return StandardAttribute.Type;
		EndIf;
		
	EndDo;
	
	// Attribute fullness for check
	For Each Attribute IN MetadataObject.Attributes Do 
		
		If Attribute.Name = FieldName Then 
			 Return Attribute.Type;
		EndIf;
		
	EndDo;
	
	// Check for general attributes
	GroupCountGeneralDetails = Metadata.CommonAttributes.Count();
	For Iteration = 0 To GroupCountGeneralDetails - 1 Do 
		
		CommonAttribute = Metadata.CommonAttributes.Get(Iteration);
		If CommonAttribute.Name <> FieldName Then 
			
			Continue;
			
		EndIf;
		
		CommonAttributeContent = CommonAttribute.Content;
		FoundCommonAttribute = CommonAttributeContent.Find(MetadataObject);
		If FoundCommonAttribute <> Undefined Then 
			
			Return CommonAttribute.Type;
			
		EndIf;
		
	EndDo;
	
EndFunction

Function LinksLimitInFile()
	
	Return 17000;
	
EndFunction

Function SourceDataColumnNewName()
	
	ColumnName = New UUID();
	ColumnName = String(ColumnName);
	ColumnName = "a" + StrReplace(ColumnName, "-", "");
	
	Return ColumnName;
	
EndFunction

Procedure WriteSourceRefsColumnName()
	
	FileName = CurrentContainer.CreateRandomFile("xml", DataExportImportService.DataTypeForValueTableColumnName());
	DataExportImportService.WriteObjectToFile(CurrentColumnNameWithSourceRef, FileName);
	
EndProcedure

Procedure WriteMatchedRefs()
	
	If CurrentRefs = Undefined
		OR CurrentRefs.Count() = 0 Then
		
		Return;
		
	EndIf;
	
	FileName = CurrentContainer.CreateFile(DataExportImportService.ReferenceMapping(), CurrentMetadataObject.FullName());
	DataExportImportService.WriteObjectToFile(CurrentRefs, FileName, CurrentSerializer);
	
	CurrentRefs.Clear();
	
EndProcedure

#EndRegion

#EndIf
