#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ObjectState

// Values table that stores vertexes and riblets of the graph. Vertexes are stored
// as values table rows, riblets - as a value of one of the columns. Table fields:
//  * UUID - UUID of the graph vertex,
//  * MetadataObject - MetadataObject of graph vertex,
//  * Riblets - Array(UUID) - array of the graph riblets,  UUID values type is used as array items.
// The values correspond to the tabular section rows that describe other graph vertexes.
//  * RibletsCount - Number - number of riblets set for the current vertex,
//  * Color - Number - saves a color of the current graph vertex. 
// Possible values - see LocalVariables module area.
//
Var CurrentGraph;

#EndRegion

#Region LocalVariables

// Digit used as a constant to indicate the white color.
//
Var White;

// Digit used as a constant to indicate the gray color.
//
Var Gray;

// Digit used as a constant to indicate the black color.
//
Var Black;

#EndRegion

#Region ServiceProgramInterface

// Adds a vertex to the graph that corresponds to the metadata object.
//
// Parameters:
//  MetadataObject - MetadataObject that corresponds to the graph vertex being added,
//  OnlyIfNotExist - Boolean - if False, then an exception is thrown whenever users try to add non-unique values.
//  Otherwise - attempt to add a non-unique value will be ignored.
//
Procedure AddVertex(Val MetadataObjectName, Val IfNotExist = True) Export
	
	MetadataObject = MetadataObject(MetadataObjectName);
	AlreadyExists = (Vertex(MetadataObject, False) <> Undefined);
	
	If AlreadyExists Then
		
		If IfNotExist Then
			Return;
		Else
			Raise NStr("en='An attempt to duplicate.';ru='Попытка дублирования!'");
		EndIf;
		
	Else
		
		Vertex = CurrentGraph.Add();
		Vertex.UUID = New UUID();
		Vertex.MetadataObject = MetadataObject;
		Vertex.Riblets = New Array();
		
	EndIf;
	
EndProcedure

// Adds a riblet to the graph that connects the vertexes.
//
// Parameters:
//  MetadataObject1 - MetadataObject that corresponds to the
//  first vertex that is connected by a riblet,
//  MetadataObject2 - MetadataObject that corresponds to the second vertex that is connected by a riblet.
//
Procedure AddRiblet(Val MetadataObjectName1, Val MetadataObjectName2) Export
	
	MetadataObject1 = MetadataObject(MetadataObjectName1);
	MetadataObject2 = MetadataObject(MetadataObjectName2);
	
	Vertex1 = Vertex(MetadataObject1);
	Vertex2 = Vertex(MetadataObject2);
	
	Vertex1.Riblets .Add(Vertex2.UUID);
	Vertex1.RibletsCount = Vertex1.RibletsCount + 1;
	
EndProcedure

// Performs topological sort of the graph vertexes and returns the sort result.
//
// Returns:
//  Array(MetadataObject) - array of metadata objects sorted as follows:
//    metadata objects that correspond to vertexes from which riblets were
//    added to other vertexes precede the metadata objects in
//    the array that correspond to vertexes that were added as riblets to other vertexes.
//
Function TopologicalSort() Export
	
	// Initially all vertexes are white
	For Each Vertex IN CurrentGraph Do
		Vertex.Color = White;
	EndDo;
	
	SortResult = New Array();
	
	For Each Vertex IN CurrentGraph Do
		
		// Make crawling in depth from each vertex
		SearchInDepth(Vertex, SortResult);
		
	EndDo;
	
	Return SortResult;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns a metadata object by its full name if the
// object does not exist in the current configuration. - exception is being generated.
//
// Parameters:
//  DescriptionFull - String - Full metadata object name.
//
// Return value: MetadataObject.
//
Function MetadataObject(Val DescriptionFull)
	
	MetadataObject = Metadata.FindByFullName(DescriptionFull);
	If MetadataObject = Undefined Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Metadata object %1 does not exist in the current configuration. The object exists in the data file.';ru='В текущей конфигурации отсутствует объект метаданных %1, присутствующих в файле данных!'"),
			DescriptionFull
		);
		
	EndIf;
	
	Return MetadataObject;
	
EndFunction

// Returns a values table row that describes the
// graph. The row corresponds to the specified metadata object.
//
// Parameters:
//  MetadataObject - MetadataObject,
//  ExceptionIfNotExist - Boolean - shows that an exception is thrown
//    if the specified metadata object does not exist in the current graph vertexes.
//
// Return value: ValuesTableRow - values table row CurrentGraph, or
//  Undefined (if the specified MetadataObject does not exist in the current graph and ExceptionIfNotExist = False).
//
Function Vertex(Val MetadataObject, Val ExceptionIfNotExist = True)
	
	FilterParameters = New Structure();
	FilterParameters.Insert("MetadataObject", MetadataObject);
	
	Rows = CurrentGraph.FindRows(FilterParameters);
	
	If Rows.Count() = 1 Then
		
		Return Rows.Get(0);
		
	ElsIf Rows.Count() = 0 Then
		
		If ExceptionIfNotExist Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='No vertex for metadata object %1 in the graph.';ru='В графе отсутствует вершина для объекта метаданных %1!'"),
				MetadataObject.FullName());
			
		Else
			
			Return Undefined;
			
		EndIf;
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Non-unique graph for metadata object %1.';ru='Нарушение уникальности граф для объекта метаданных %1!'"),
			MetadataObject.FullName());
		
	EndIf;
	
EndFunction

// Search deeper on topological sort.
//
// Parameters:
//  Vertex - ValueTableRow - values table row CurrentGraph,
//  SortResult - Array(MetadataObject) - topological sort result.
//
Procedure SearchInDepth(Vertex, SortResult)
	
	// If it is a gray vertex - a cycle is found, can not process topological sort
	If Vertex.Color = Gray Then
		
		Raise NStr("en='Recursive dependence.';ru='Рекурсивная зависимость!'");
		
	ElsIf Vertex.Color = White Then
		
		// When accessing the vertex, make it gray
		Vertex.Color = Gray;
		
		// Make crawling in depth from each vertex
		For Each Riblet IN Vertex.Riblets Do
			SearchInDepth(CurrentGraph.Find(Riblet, "UUID"), SortResult);
		EndDo;
		
		// When going out of the vertex, make it black
		Vertex.Color = Black;
		// Simultaneously put it into stack.
		SortResult.Add(Vertex.MetadataObject);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Initialization

CurrentGraph = New ValueTable();
CurrentGraph.Columns.Add("UUID", New TypeDescription("UUID"));
CurrentGraph.Columns.Add("MetadataObject");
CurrentGraph.Columns.Add("Riblets", New TypeDescription("Array"));
CurrentGraph.Columns.Add("RibletsCount", New TypeDescription("Number"));
CurrentGraph.Columns.Add("Color", New TypeDescription("Number"));
CurrentGraph.Indexes.Add("UUID");

White = 1;
Gray = 2;
Black = 3;

#EndRegion

#EndIf