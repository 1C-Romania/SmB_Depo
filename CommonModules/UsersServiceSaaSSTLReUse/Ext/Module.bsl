#Region ServiceProgramInterface

//Reads from the constant information about the registers and forms the compliance for RegistersListReferencesToUsers
//
Function RecordSetListWithReferencesToUsers() Export
	
	SetPrivilegedMode(True);
	MetadataDescription = RecordSetsWithefsToUsers();
	
	MetadataList = New Map;
	For Each String IN MetadataDescription Do
		MetadataList.Insert(Metadata[String.Collection][String.Object], String.Dimensions);
	EndDo;
	
	Return MetadataList;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns record sets, fields content, for which the CatalogRef
// type is set as a value type.Users.
//
// Return value: ValuesTable:
//                         * Collection - String - name of
//                         the metadata collection, *Object - String - name of
//                         the metadata object, *Measurements - Array(Row) - names of the measurements.
//
Function RecordSetsWithefsToUsers()
	
	MetadataDescription = New ValueTable;
	MetadataDescription.Columns.Add("Collection", New TypeDescription("String"));
	MetadataDescription.Columns.Add("Object", New TypeDescription("String"));
	MetadataDescription.Columns.Add("Dimensions", New TypeDescription("Array"));
	
	For Each InformationRegister IN Metadata.InformationRegisters Do
		AddToMetadataList(MetadataDescription, InformationRegister, "InformationRegisters");
	EndDo;
	
	For Each Sequence IN Metadata.Sequences Do
		AddToMetadataList(MetadataDescription, Sequence, "Sequences");
	EndDo;
	
	Return MetadataDescription;
	
EndFunction

Procedure AddToMetadataList(Val MetadataList, Val ObjectMetadata, Val CollectionName)
	
	UserRefType = Type("CatalogRef.Users");
	
	Dimensions = New Array;
	For Each Dimension IN ObjectMetadata.Dimensions Do 
		
		If (Dimension.Type.ContainsType(UserRefType)) Then
			Dimensions.Add(Dimension.Name);
		EndIf;
		
	EndDo;
	
	If Dimensions.Count() > 0 Then
		String = MetadataList.Add();
		String.Collection = CollectionName;
		String.Object = ObjectMetadata.Name;
		String.Dimensions = Dimensions;
	EndIf;
	
EndProcedure

#EndRegion