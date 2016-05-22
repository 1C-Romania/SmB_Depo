#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

Procedure StandardRefsMapping(RefReplacementStream, Val MetadataObject, Val SourceRefsTable, Val RefsMappingManager) Export
	
	XMLTypeName = DataExportImportService.XMLReferenceType(MetadataObject);
	
	SourceRefColumnName = RefsMappingManager.SourceRefsColumnName();
	
	Selection = MatchRefsSelection(MetadataObject, SourceRefsTable, SourceRefColumnName);
	
	While Selection.Next() Do
		
		RefReplacementStream.ReplaceRef(XMLTypeName, String(Selection[SourceRefColumnName].UUID()),
			String(Selection.Ref.UUID()));
		
	EndDo;
	
EndProcedure

Function MatchRefsSelection(Val MetadataObject, Val SourceRefsTable, Val SourceRefColumnName) Export
	
	KeyFields = New Array();
	For Each KeyColumn IN SourceRefsTable.Columns Do
		If KeyColumn.Name <> SourceRefColumnName Then
			KeyFields.Add(KeyColumn.Name);
		EndIf;
	EndDo;
	
	MatchingQueryText = GenerateMatchingQueryTextRefsByNaturalKeys(
		MetadataObject, SourceRefsTable.Columns, SourceRefColumnName);
	
	Query = New Query(MatchingQueryText);
	Query.SetParameter("SourceRefsTable", SourceRefsTable);
	
	Return Query.Execute().Select();
	
EndFunction

// Create query to get references to unseparated data in IB
//
// Returns:
//  String
//
Function GenerateMatchingQueryTextRefsByNaturalKeys(Val MetadataObject, Val Columns, Val SourceRefColumnName)
	
	QueryText =
	"SELECT
	|	SourceRefsTable.*
	|INTO SourceRefs
	|FROM
	|	&SourceRefsTable AS SourceRefsTable;
	|SELECT
	|	SourceRefs.%SourceRef AS %SourceRef,
	|	_ImportXML_Table.Ref AS Ref
	|FROM
	|	SourceRefs AS SourceRefs
	|	INNER JOIN " + MetadataObject.FullName() + " AS _XMLImport_Tale ";
	
	Iteration = 1;
	For Each Column IN Columns Do 
		
		If Column.Name = SourceRefColumnName Then 
			Continue;
		EndIf;
		
		QueryText = QueryText + "%LogicalFunction (SourceRefs.%KeyName = _ImportXML_Table.%KeyName) ";
		
		LogicalFunction = ?(Iteration = 1, "ON", "AND");
		
		QueryText = StrReplace(QueryText, "%KeyName",          Column.Name);
		QueryText = StrReplace(QueryText, "%LogicalFunction", LogicalFunction);
		
		Iteration = Iteration + 1;
		
	EndDo;
	
	QueryText = StrReplace(QueryText, "%SourceRef", SourceRefColumnName);
	
	Return QueryText;
	
EndFunction

#EndRegion

#EndIf