
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	CurrentPosition = 0;
	
	Items.GoToNext.Enabled = False;
	Items.Back.Enabled = False;
	
	Array = CommonUse.CommonSettingsStorageImport("FulltextSearchFulltextSearchStrings");
	
	If Array <> Undefined Then
		Items.SearchString.ChoiceList.LoadValues(Array);
	EndIf;
	
	If Not IsBlankString(Parameters.TransferredSearchString) Then
		SearchString = Parameters.TransferredSearchString;
		
		SaveSearchString(Items.SearchString.ChoiceList, SearchString);
		Try
			Result = PerformSearchServer(0, CurrentPosition, SearchString);
		Except	
			CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()));
			Return;
		EndTry;
		
		SearchResults = Result.SearchResult;
		HTMLText = Result.HTMLText;
		CurrentPosition = Result.CurrentPosition;
		TotalQuantity = Result.TotalQuantity;
		
		If SearchResults.Count() <> 0 Then
			
			ShowedResultsFromTo = StringFunctionsClientServer.PlaceParametersIntoString(
			                            NStr("en = 'Shown %1 - %2 from %3'"),
			                            String(CurrentPosition + 1),
			                            String(CurrentPosition + SearchResults.Count()),
			                            String(TotalQuantity) );
			
			Items.GoToNext.Enabled = (TotalQuantity - CurrentPosition) > SearchResults.Count();
			Items.Back.Enabled = (CurrentPosition > 0);
		Else
			ShowedResultsFromTo = NStr("en = 'Not found'");
			Items.GoToNext.Enabled = False;
			Items.Back.Enabled = False;
		EndIf;
	Else
		HTMLText = 
		"<html>
		|<head>
		|<meta http-equiv=""Content-Style-Type"" content=""text/css"">
		|</head>
		|<body topmargin=0 leftmargin=0 scroll=auto>
		|<table border=""0"" width=""100%"" cellspacing=""5"">
		|</table>
		|</body>
		|</html>";
	EndIf;	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure SearchStringOnChange(Item)
	
	Cancel = False;
	
	Search(0, Cancel);
	
	If Not Cancel Then
		CurrentItem = Items.SearchString;
	EndIf;
	
EndProcedure

&AtClient
Procedure SearchStringChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	SearchString = ValueSelected;
	Search(0);
	
EndProcedure

&AtClient
Procedure HTMLTextOnClick(Item, EventData, StandardProcessing)
	HTMLElement = EventData.Anchor;
	
	If HTMLElement = Undefined Then
		Return;
	EndIf;
	
	If (HTMLElement.id = "FullTextSearchListItem") Then
		StandardProcessing = False;
		
		URLPart = HTMLElement.outerHTML;
		Position = Find(URLPart, "sel_num=");
		URLPartClipped = Mid(URLPart, Position + 9);
		PositionEnding = Find(URLPartClipped, """");
		If PositionEnding = 0 Then
			PositionEnding = Find(URLPartClipped, "'");
			If PositionEnding = 0 Then
				PositionEnding = 2;
			EndIf;
		EndIf;
		If Position <> 0 Then
			URLPart = Mid(URLPartClipped, 1, PositionEnding - 1);
		EndIf;
			
		NumberInList = Number(URLPart);
		ResultStructure = SearchResults[NumberInList].Value;
		SelectedRow = ResultStructure.Value;
		ObjectsArray = ResultStructure.ValuesForOpening;
		
		If ObjectsArray.Count() = 1 Then
			OpenSearchValue(ObjectsArray[0]);
		ElsIf ObjectsArray.Count() <> 0 Then
			List = New ValueList;
			For Each ArrayElement IN ObjectsArray Do
				List.Add(ArrayElement);
			EndDo;
			
			Handler = New NotifyDescription("HTMLTextOnClickAfterSelectFromList", ThisObject);
			ShowChooseFromList(Handler, List, Items.HTMLText);
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RunSearch(Command)
	
	Search(0);
	
EndProcedure

&AtClient
Procedure TheFollowing(Command)
	
	Search(1);
	
EndProcedure

&AtClient
Procedure Previous(Command)
	
	Search(-1);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure OpenSearchValue(Value)
	
	ShowValue(, Value);

EndProcedure

&AtClient
Procedure Search(Direction, Cancel = Undefined)
	// Search procedure, getting and displaying the result.
	
	If IsBlankString(SearchString) Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Enter search string.'"), , "SearchString");
		Cancel = True;
		Return;
	EndIf;
	
	ThisIsURL = Find(SearchString, "e1cib/data/") <> 0;
	If ThisIsURL Then
		GotoURL(SearchString);
		SearchString = "";
		Return;
	EndIf;
	
	Status(StringFunctionsClientServer.PlaceParametersIntoString(NStr("en = 'Searching ""%1""...'"), SearchString));
	
	ChoiceList = Items.SearchString.ChoiceList.Copy();
	Result = SaveStringAndPerformSearchServer(Direction, CurrentPosition, SearchString, ChoiceList);
	Items.SearchString.ChoiceList.Clear();
	For Each ChoiceListItem IN ChoiceList Do
		Items.SearchString.ChoiceList.Add(ChoiceListItem.Value, ChoiceListItem.Presentation);
	EndDo;
	
	SearchResults = Result.SearchResult;
	HTMLText = Result.HTMLText;
	CurrentPosition = Result.CurrentPosition;
	TotalQuantity = Result.TotalQuantity;
	
	If SearchResults.Count() > 0 Then
		
		ShowedResultsFromTo = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Shown %1 - %2 from %3'"),
			Format(CurrentPosition + 1, "NZ=0; NG="),
			Format(CurrentPosition + SearchResults.Count(), "NZ=0; NG="),
			Format(TotalQuantity, "NZ=0; NG="));
		
		Items.GoToNext.Enabled = (TotalQuantity - CurrentPosition) > SearchResults.Count();
		Items.Back.Enabled = (CurrentPosition > 0);
		
		If Direction = 0 AND Result.CurrentPosition = 0 AND Result.TooManyResults Then
			ShowMessageBox(, NStr("en = 'Too many results, refine query.'"));
		EndIf;
	
	Else
		
		ShowedResultsFromTo = NStr("en = 'Not found'");
		
		Items.GoToNext.Enabled = False;
		Items.Back.Enabled = False;
		
		SearchText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Words combination ""%1"" can not be found anywhere.<br><br>
			|<b>Recommendations:</b>
			|<li>Make sure all words are written correctly.
			|<> Try to use other key words.
			|<li>Try to reduce the number of the searched words.'"),
			TrimAll(SearchString));
		
		HTMLText = 
		"<html>
		|<head>
		|<meta http-equiv=""Content-Style-Type""
		|content=""text/css""> <style>H1
		|{ TEXT-ALIGN: left; FONT-FAMILY: Arial, Tahoma; COLOR: #003366; FONT-SIZE: 18pt;
		|FONT-WEIGHT:
		|bold }
		|.Programtext { FONT-FAMILY: Courier; COLOR: #000080;
		|FONT-SIZE:
		|10pt
		|} H3 { TEXT-ALIGN: left; FONT-FAMILY: Arial, Tahoma; FONT-SIZE:
		|11pt;
		|FONT-WEIGHT: bold
		|} H4 { TEXT-ALIGN: left; FONT-FAMILY: Arial, Tahoma; FONT-SIZE:
		|10pt;
		|FONT-WEIGHT: bold
		|} BODY { FONT-FAMILY:
		|Verdana;
		|FONT-SIZE:
		|8pt }</style> </head> <body scroll=auto>
		|" + SearchText + "
		|</body>
		|</html>";
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetValuesForOpening(Object)
	// Returns an array of objects (possibly from the one item) for displaying to user.
	Result = New Array;
	
	// Object of the reference type
	If CommonUse.ReferenceTypeValue(Object) Then
		Result.Add(Object);
		Return Result;
	EndIf;
	
	ObjectMetadata = Metadata.FindByType(TypeOf(Object));
	NameMetadata = ObjectMetadata.Name;
	
	FullObjectName = Upper(Metadata.FindByType(TypeOf(Object)).FullName());
	ThisIsInformationRegister = (Find(FullObjectName, "INFORMATIONREGISTER.") > 0);

	If Not ThisIsInformationRegister Then // Accounting register or accumulation or calculation.
		Recorder = Object["Recorder"];
		Result.Add(Recorder);
		Return Result;
	EndIf;

	// below - this is already an information register.
	If ObjectMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate Then
		Recorder = Object["Recorder"];
		Result.Add(Recorder);
		Return Result;
	EndIf;

	// Independent
	// information register at first - main types.
	For Each Dimension IN ObjectMetadata.Dimensions Do
		If Dimension.Master Then 
			ValueDimensions = Object[Dimension.Name];
			
			If CommonUse.ReferenceTypeValue(ValueDimensions) Then
				Result.Add(ValueDimensions);
			EndIf;
			
		EndIf;
	EndDo;

	If Result.Count() = 0 Then
		// now - any types
		For Each Dimension IN ObjectMetadata.Dimensions Do
			If Dimension.Master Then 
				ValueDimensions = Object[Dimension.Name];
				Result.Add(ValueDimensions);
			EndIf;
		EndDo;
	EndIf;
	
	// There is no one leading dimension - return the information register key itself.
	If Result.Count() = 0 Then
		Result.Add(Object);
	EndIf;

	Return Result;
EndFunction

&AtServerNoContext
Function SaveStringAndPerformSearchServer(Direction, CurrentPosition, SearchString, ChoiceList)
	// Procedure executes a fulltext search.
	
	SaveSearchString(ChoiceList, SearchString);
	
	Return PerformSearchServer(Direction, CurrentPosition, SearchString);
	
EndFunction

&AtServerNoContext
Procedure SaveSearchString(ChoiceList, SearchString)
	
	SavedString = ChoiceList.FindByValue(SearchString);
	
	If SavedString <> Undefined Then
		ChoiceList.Delete(SavedString);
	EndIf;
		
	ChoiceList.Insert(0, SearchString);
	
	LineCount = ChoiceList.Count();
	
	If LineCount > 20 Then
		ChoiceList.Delete(LineCount - 1);
	EndIf;
	
	Rows = ChoiceList.UnloadValues();
	
	CommonUse.CommonSettingsStorageSave(
		"FulltextSearchFulltextSearchStrings", 
		, 
		Rows);
	
EndProcedure

&AtServerNoContext
Function PerformSearchServer(Direction, CurrentPosition, SearchString)
	// Procedure executes a fulltext search.
	
	PortionSize = 20;
	
	SearchList = FullTextSearch.CreateList(SearchString, PortionSize);
	
	If Direction = 0 Then
		SearchList.FirstPart();
	ElsIf Direction = -1 Then
		SearchList.PreviousPart(CurrentPosition);
	ElsIf Direction = 1 Then
		SearchList.NextPart(CurrentPosition);
	EndIf;
	
	SearchResults = New ValueList;
	For Each Result IN SearchList Do
		ResultStructure = New Structure;
		ResultStructure.Insert("Value", Result.Value);
		ResultStructure.Insert("ValuesForOpening", GetValuesForOpening(Result.Value));
		SearchResults.Add(ResultStructure);
	EndDo;
	
	HTMLText = SearchList.GetRepresentation(FullTextSearchRepresentationType.HTMLText);
	
	HTMLText = StrReplace(HTMLText, "<td>", "<td><font face=""Arial"" size=""2"">");
	HTMLText = StrReplace(HTMLText, "<td valign=top width=1>", "<td valign=top width=1><font face=""Arial"" size=""1"">");
	HTMLText = StrReplace(HTMLText, "<body>", "<body topmargin=0 leftmargin=0 scroll=auto>");
	HTMLText = StrReplace(HTMLText, "</td>", "</font></td>");
	HTMLText = StrReplace(HTMLText, "<b>", "");
	HTMLText = StrReplace(HTMLText, "</b>", "");
	HTMLText = StrReplace(HTMLText, "overflow:auto", "");
	
	CurrentPosition = SearchList.StartPosition();
	TotalQuantity = SearchList.TotalCount();
	TooManyResults = SearchList.TooManyResults();
	
	Result = New Structure;
	Result.Insert("SearchResult", SearchResults);
	Result.Insert("CurrentPosition", CurrentPosition);
	Result.Insert("TotalQuantity", TotalQuantity);
	Result.Insert("HTMLText", HTMLText);
	Result.Insert("TooManyResults", TooManyResults);
	
	Return Result;
	
EndFunction

&AtClient
Procedure HTMLTextOnClickAfterSelectFromList(SelectedItem, AdditionalParameters) Export
	If SelectedItem <> Undefined Then
		OpenSearchValue(SelectedItem.Value);
	EndIf;
EndProcedure

#EndRegion
