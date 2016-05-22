
#Region ServiceProceduresAndFunctions

// Tag creation function
//
// Parameters:
//  TagName - String - tag
// name Return value:
//  CatalogRef.Tags - reference to created item
Function CreateTag(TagName) Export
	
	Return ContactsClassification.CreateTag(TagName);
	
EndFunction

// Function of receiving counterperties by tags.
//
// Parameters:
//  Tags - array - CatalogRef.Tags - tags by which the
// Return value counterparties should be received:
//  array - CatalogRef.Counterparties - counterparties containing all specified tags.
Function CounterpartiesByTags(Tags) Export
	
	Counterparties = New Array;
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	Counterparties.Ref AS Counterparty,
		|	Counterparties.Tags.(
		|		Tag
		|	)
		|FROM
		|	Catalog.Counterparties AS Counterparties";
	
	SelectionCounterparties = Query.Execute().Select();
	Filter = New Structure("Tag");
	
	While SelectionCounterparties.Next() Do
		
		SelectionTags = SelectionCounterparties.Tags.Select();
		HasAllTags = True;
		
		For Each Tag IN Tags Do
			Filter.Tag = Tag;
			SelectionTags.Reset();
			If Not SelectionTags.FindNext(Filter) Then
				HasAllTags = False;
				Break;
			EndIf;
		EndDo;
		
		If HasAllTags Then
			Counterparties.Add(SelectionCounterparties.Counterparty);
		EndIf;
		
	EndDo;
	
	Return Counterparties;
	
EndFunction

// Function of receiving counterperties by segments.
//
// Parameters:
//  Segments - array - CatalogRef.Segments - segments for which the
// Return value counterparties should be received:
//  array - CatalogRef.Counterparties - counterparties of segments.
Function SegmentsCounterparties(Segments) Export
	
	Counterparties = New Array;
	
	For Each Segment IN Segments Do
		
		SegmentComposition = Catalogs.Segments.GetSegmentComposition(Segment);
		
		If Counterparties.Count() = 0 Then
			Counterparties = SegmentComposition;
		Else
			Counterparties = SmallBusinessClientServer.GetMatchingArraysItems(Counterparties, SegmentComposition);
		EndIf;
		
	EndDo;
	
	Return Counterparties;
	
EndFunction

// Function of receiving counterperties by tags and segments. Filters add up according
// to the logical "AND" i.e. counterparties that do not meet at least one specified filter are cut out.
//
// Parameters:
//  Tags - array - CatalogRef.Tags - tags by which the
//  Segments counterparties should be received - array - CatalogRef.Segments - segments for which the
// Return value counterparties should be received:
//  array - CatalogRef.Counterparties - counterperties by tags and segments.
Function CounterpartiesByTagsAndSegments(Tags, Segments) Export
	
	Counterparties = New Array;
	
	If Tags.Count() > 0 AND Segments.Count() > 0 Then
		Counterparties = SmallBusinessClientServer.GetMatchingArraysItems(CounterpartiesByTags(Tags), SegmentsCounterparties(Segments));
	ElsIf Tags.Count() > 0 Then
		Counterparties = CounterpartiesByTags(Tags);
	ElsIf Segments.Count() > 0 Then
		Counterparties = SegmentsCounterparties(Segments);
	EndIf;
	
	Return Counterparties;
	
EndFunction

#EndRegion
