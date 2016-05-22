////////////////////////////////////////////////////////////////////////////////
// Subsystem "Objects prefixation".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Returns the table of prefix-forming attributes that are specified in the overridable module.
//
Function PrefixesGeneratingAttributes() Export
	
	Objects = New ValueTable;
	Objects.Columns.Add("Object");
	Objects.Columns.Add("Attribute");
	
	ObjectPrefixationOverridable.GetPrefixesGeneratingAttributes(Objects);
	
	ObjectsAttributes = New Map;
	
	For Each String IN Objects Do
		ObjectsAttributes.Insert(String.Object.FullName(), String.Attribute);
	EndDo;
	
	Return New FixedMap(ObjectsAttributes);
	
EndFunction

#EndRegion
