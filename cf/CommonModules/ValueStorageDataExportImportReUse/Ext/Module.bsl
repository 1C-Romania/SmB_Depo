////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data export import".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Returns a list of metadata objects that have properties for which the ValueStorage type is used.
//
// Returns:
//  FixedMap:
//    * Key - String, the full name of metadata object, * Value - Array(Structure), fields of structure:
//       * AttributeName - String, name of the property, * TabularSectionName - String, tabular section name (used only for attributes of objects tabular section).
//
Function MetadataObjectListWithValueStorage() Export
	
	ValueStorageType = Type("ValueStorage");
	
	MetadataList = New Map;
	
	For Each ObjectMetadata IN DataExportImportService.AllConstants() Do
		AddConstantToMetadataList(ObjectMetadata, MetadataList);
	EndDo;
	
	For Each ObjectMetadata IN DataExportImportService.AllReferenceData() Do
		AddReferenceTypeToMetadataList(ObjectMetadata, MetadataList);
	EndDo;
	
	For Each ObjectMetadata IN DataExportImportService.AllRecordSets() Do
		AddRegisterToMetadataTable(ObjectMetadata, MetadataList);
	EndDo;
	
	Return New FixedMap(MetadataList);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Adds a constant to the metadata list if it contains storage of values.
//
// Parameters:
// Metadata - Metadata - Metadata
// MetadataList - see return value "MetadataListWithValueStorage"
//
Procedure AddConstantToMetadataList(Metadata, MetadataList)
	
	ValueStorageType = Type("ValueStorage");
	
	If Not Metadata.Type.ContainsType(ValueStorageType) Then 
		Return;
	EndIf;
	
	MetadataList.Insert(Metadata.FullName(), New Array);
	
EndProcedure

// Adds a reference type to the metadata list if it contains storage of values.
//
// Parameters:
// Metadata - Metadata - Metadata
// MetadataList - see return value "MetadataListWithValueStorage"
//
Procedure AddReferenceTypeToMetadataList(Metadata, MetadataList)
	
	StructuresArray = New Array;
	
	For Each Attribute IN Metadata.Attributes Do 
		
		AddAttributeToArray(StructuresArray, Attribute);
		
	EndDo;
	
	For Each TabularSection IN Metadata.TabularSections Do 
		
		For Each Attribute IN TabularSection.Attributes Do
			
			AddAttributeToArray(StructuresArray, Attribute, TabularSection);
			
		EndDo;
		
	EndDo;
	
	InsertMetadataWithValueStorageInAccordance(Metadata.FullName(), MetadataList, StructuresArray);
	
EndProcedure

// Adds a reference type to the metadata list if it contains storage of values.
//
// Parameters:
// Metadata - Metadata - Metadata
// MetadataList - see return value "MetadataListWithValueStorage"
//
Procedure AddRegisterToMetadataTable(Val ObjectMetadata, Val MetadataList)
	
	StructuresArray = New Array;
	
	For Each Dimension IN ObjectMetadata.Dimensions Do 
		
		If Metadata.CalculationRegisters.Contains(ObjectMetadata.Parent()) Then
			Dimension = Dimension.RegisterDimension;
		EndIf;
		AddAttributeToArray(StructuresArray, Dimension);
		
	EndDo;
	
	If Metadata.Sequences.Contains(ObjectMetadata) 
		Or Metadata.CalculationRegisters.Contains(ObjectMetadata.Parent()) Then 
		
		Return;
		
	EndIf;
	
	For Each Attribute IN ObjectMetadata.Attributes Do 
		
		AddAttributeToArray(StructuresArray, Attribute);
		
	EndDo;
	
	For Each Resource IN ObjectMetadata.Resources Do 
		
		AddAttributeToArray(StructuresArray, Resource);
		
	EndDo;
	
	InsertMetadataWithValueStorageInAccordance(ObjectMetadata.FullName(), MetadataList, StructuresArray);
	
EndProcedure

// Generates the array of structures with the attributes that store the value storage.
//
// Parameters:
// StructuresArray - Array - array of structures.
// Attribute - MetadataObject - attribute.
// TabularSection - MetadataObject - tabular section.
//
Procedure AddAttributeToArray(StructuresArray, Attribute, TabularSection = Undefined)
	
	ValueStorageType = Type("ValueStorage");
	
	If Not Attribute.Type.ContainsType(ValueStorageType) Then 
		Return;
	EndIf;
	
	AttributeName      = Attribute.Name;
	TabularSectionName = ?(TabularSection = Undefined, Undefined, TabularSection.Name);
	
	Structure = AttributesStructureWithValuesStorage();
	Structure.TabularSectionName = TabularSectionName;
	Structure.AttributeName      = AttributeName;
	
	StructuresArray.Add(Structure);
	
EndProcedure

// Adds metadata to the metadata list in the attribute of which there is a storage of values.
//
// Parameters:
// FullMetadataName - String - metadata name.
// MetadataList - see return value
// "MetadataListWithValueStorage" StructuresArray - Array - array of structures: see "AttributesStructureWithValuesStorage"
//
Procedure InsertMetadataWithValueStorageInAccordance(FullMetadataName, MetadataList, StructuresArray)
	
	If StructuresArray.Count() = 0 Then 
		Return;
	EndIf;
	
	MetadataList.Insert(FullMetadataName, StructuresArray);
	
EndProcedure

// Returns a structure that stores information about the attribute that stores a storage of values.
//
// Returns:
// Structure - structure.
//
Function AttributesStructureWithValuesStorage()
	
	Result = New Structure;
	Result.Insert("TabularSectionName");
	Result.Insert("AttributeName");
	
	Return Result;
	
EndFunction

#EndRegion