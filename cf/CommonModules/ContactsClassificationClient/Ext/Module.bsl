
#Region AttributesEventsHandlers

// Procedure - event handler "OnChange" for tag input field in the form of the object
//
// Parameters:
//  Form	 - object form
//  form Item	 - tag input field
Procedure TagOnChange(Form, Item) Export
	
	PlaceTagToTablularSection(Form);
	
EndProcedure

// Procedure - event handler "URLProcessing" for field of tag value in the form of the object
//
// Parameters:
//  Form				 - object form
//  Item				 - form item - tag value 
//  NavigationRef	 - String - navigation reference containing tag ID 
//  StandardDataProcessor - Boolean - standard navigation reference processor
Procedure TagURLProcessing(Form, Item, URL, StandardProcessing) Export
	
	If Left(URL, 6) <> "TagID_" Then
		Return;
	EndIf;
	
	Object = Form.Object;
	
	StandardProcessing = False;
	Form.Modified = True;
	
	Form.LockFormDataForEdit();
	
	TagID = Mid(URL, 7);
	ItemOfList = Object.Tags.FindByID(TagID);
	
	Object.Tags.Delete(ItemOfList);
	
	Form.UpdateTagsCloud();
	
EndProcedure

// Function - events handler "Pressing" for predefined period options or events "OnChange" for arbitrary period
//
// Parameters:
//  Form			 - list form
//  ListName		 - String - name of form dynamic list for which
//  the filter is set PeriodOption	 - String - takes values: "Custom", "Today", "3days", "Week", "Month"
//  Item			 - item form
//  Return value:
//  Boolean - filter by the element is enabled or disabled
Function CreatedFilterClick(Form, ListName, PeriodVariant, Item) Export
	
	If PeriodVariant = "Custom" Then
		PeriodNumber = 0;
	ElsIf PeriodVariant = "Today" Then
		PeriodNumber = 1;
	ElsIf PeriodVariant = "3Days" Then
		PeriodNumber = 2;
	ElsIf PeriodVariant = "Week" Then
		PeriodNumber = 3;
	ElsIf PeriodVariant = "Month" Then
		PeriodNumber = 4;
	EndIf;
	
	Period = Form.FilterCreated[PeriodNumber];
	If PeriodNumber = 0 Then
		If ValueIsFilled(Period.Value.StartDate) Or ValueIsFilled(Period.Value.EndDate) Then
			Period.Check = True;
		Else
			Period.Check = False;
		EndIf;
	Else
		Period.Check = Not Period.Check;
	EndIf;
	
	// You can select only one period option
	For IndexOf = 0 To Form.FilterCreated.Count()-1 Do
		
		PeriodsListItem = Form.FilterCreated[IndexOf];
		If PeriodsListItem <> Period Then
			PeriodsListItem.Check = False;
		EndIf;
		
		If IndexOf = 0 Then
			PeriodDisplayItem = Form.Items.FilterCreatedCustomPeriod;
		ElsIf IndexOf = 1 Then
			PeriodDisplayItem = Form.Items.FilterCreatedToday;
		ElsIf IndexOf = 2 Then
			PeriodDisplayItem = Form.Items.FilterCreatedOver3Days;
		ElsIf IndexOf = 3 Then
			PeriodDisplayItem = Form.Items.FilterCreatedOverWeek;
		ElsIf IndexOf = 4 Then
			PeriodDisplayItem = Form.Items.FilterCreatedOverMonth;
		Else
			Continue;
		EndIf;
		
		If PeriodsListItem.Check Then
			PeriodDisplayItem.BackColor = CommonUseClientReUse.StyleColor("FilterActiveValueBackground");
		Else
			PeriodDisplayItem.BackColor = New Color;
		EndIf;
		
	EndDo;
	
	GenerateFilterOptionTitle(Form.Items.FilterPeriod, CommonUseClientServer.GetArrayOfMarkedListItems(Form.FilterCreated).Count());
	
	FilterGroupPeriod = CommonUseClientServer.CreateGroupOfFilterItems(Form[ListName].Filter.Items, "FilterPeriod", DataCompositionFilterItemsGroupType.AndGroup);
	FilterGroupPeriod.Use = Period.Check;
	If FilterGroupPeriod.Items.Count() = 0 Then
		
		FilterItem = FilterGroupPeriod.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("CreationDate");
		FilterItem.ComparisonType = DataCompositionComparisonType.GreaterOrEqual;
		FilterItem.RightValue = Period.Value.StartDate;
		FilterItem.Use = True;
		
		FilterItem = FilterGroupPeriod.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("CreationDate");
		FilterItem.ComparisonType = DataCompositionComparisonType.LessOrEqual;
		FilterItem.RightValue = Period.Value.EndDate;
		FilterItem.Use = True;
		
	ElsIf FilterGroupPeriod.Items.Count() = 2 Then
		
		FilterGroupPeriod.Items[0].RightValue = Period.Value.StartDate;
		FilterGroupPeriod.Items[1].RightValue = Period.Value.EndDate;
		
	EndIf;
	
	Return Period.Check;
	
EndFunction

// Function - events handler "Click" for fields-tags in the form of the list
//
// Parameters:
//  Form				 - list form
//  ListName			 - String - name of form dynamic list for which
//  the filter is set Item				 - form
//  item StandardDataProcessor - Boolean - standard processing
// of clicking Return value:
//  Boolean - filter by the element is enabled or disabled
Function TagFilterClick(Form, ListName, Item, StandardProcessing) Export
	
	If Left(Item.Name, 4) <> "Tag_" Then
		Return Undefined;
	EndIf;
	
	StandardProcessing = False;
	
	If Item.Name = "Tag_Explanation" Then
		OpenParameters = New Structure("Title, ToolTipKey", 
			"How to work with tags",
			"CounterpartiesClassification_HowToWorkWithTags");
		OpenForm("DataProcessor.ToolTipManager.Form", OpenParameters, , Form.UUID);
		Return Undefined;
	EndIf;
	
	TagID = Mid(Item.Name, 5);
	ItemOfList = Form.FilterTags.FindByID(TagID);
	ItemOfList.Check = Not ItemOfList.Check;
	
	Tags = CommonUseClientServer.GetArrayOfMarkedListItems(Form.FilterTags);
	Segments = CommonUseClientServer.GetArrayOfMarkedListItems(Form.FilterSegments);
	GenerateFilterOptionTitle(Form.Items.FilterTags, Tags.Count());
	
	Counterparties = New Array;
	If Tags.Count() > 0 Or Segments.Count() > 0 Then
		Counterparties = ContactsClassificationServerCall.CounterpartiesByTagsAndSegments(Tags, Segments);
		FilterIsOn = True;
	Else
		Counterparties = New Array;
		FilterIsOn = False;
	EndIf;
	
	CommonUseClientServer.SetFilterDynamicListItem(Form[ListName], "Ref", Counterparties, DataCompositionComparisonType.InList, , FilterIsOn);
	
	Return ItemOfList.Check;
	
EndFunction

// Function - events handler "Click" for fields-segments in the form of the list
//
// Parameters:
//  Form				 - list
//  form ListName			 - String - name of form dynamic list for which
//  the filter is set Item				 - form
//  item StandardDataProcessor - Boolean - standard processing
// of clicking Return value:
//  Boolean - filter by the element is enabled or disabled
Function SegmentFilterClick(Form, ListName, Item, StandardProcessing) Export
	
	If Left(Item.Name, 8) <> "Segment_" Then
		Return Undefined;
	EndIf;
	
	StandardProcessing = False;
	
	If Item.Name = "Segment_Explanation" Then
		OpenParameters = New Structure("Title, ToolTipKey", 
			"How to work with segments",
			"CounterpartiesClassification_HowToWorkWithSegments");
		OpenForm("DataProcessor.ToolTipManager.Form", OpenParameters, , Form.UUID);
		Return Undefined;
	EndIf;
	
	SegmentID = Mid(Item.Name, 9);
	ItemOfList = Form.FilterSegments.FindByID(SegmentID);
	ItemOfList.Check = Not ItemOfList.Check;
	
	Tags = CommonUseClientServer.GetArrayOfMarkedListItems(Form.FilterTags);
	Segments = CommonUseClientServer.GetArrayOfMarkedListItems(Form.FilterSegments);
	GenerateFilterOptionTitle(Form.Items.FilterSegments, Segments.Count());
	
	Counterparties = New Array;
	If Tags.Count() > 0 Or Segments.Count() > 0 Then
		Counterparties = ContactsClassificationServerCall.CounterpartiesByTagsAndSegments(Tags, Segments);
		FilterIsOn = True;
	Else
		Counterparties = New Array;
		FilterIsOn = False;
	EndIf;
	
	CommonUseClientServer.SetFilterDynamicListItem(Form[ListName], "Ref", Counterparties, DataCompositionComparisonType.InList, , FilterIsOn);
	
	Return ItemOfList.Check;
	
EndFunction

#EndRegion

#Region CommandHandlers

// Procedure - handler of filter option change on filter panel
//
// Parameters:
//  Form	 - list
//  form Command	 - form command
Procedure SelectFilterVariant(Form, Command) Export
	
	Items = Form.Items;
	
	If Command.Name = "FilterPeriod" Then
		PageName = "FilterValuesPeriod";
	ElsIf Command.Name = "FilterTags" Then
		PageName = "FilterValuesTags";
	ElsIf Command.Name = "FilterSegments" Then
		PageName = "FilterValuesSegments";
	Else
		Return;
	EndIf;
	
	PageForDisplay = Items.Find(PageName);
	If PageForDisplay = Undefined Then
		Return;
	EndIf;
	
	If Items.FilterValuesPanel.Visible AND Items.FilterValuesPanel.CurrentPage = PageForDisplay Then
		Items.FilterValuesPanel.Visible = False;
		Items[Command.Name].BackColor = New Color;
	Else
		Items.FilterValuesPanel.Visible = True;
		Items.FilterValuesPanel.CurrentPage = PageForDisplay;
		Items.FilterPeriod.BackColor = New Color;
		Items.FilterTags.BackColor = New Color;
		Items.FilterSegments.BackColor = New Color;
		Items[Command.Name].BackColor = CommonUseClientReUse.StyleColor("FilterActiveValueBackground");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure PlaceTagToTablularSection(Form)
	
	If Not ValueIsFilled(Form.Tag) Then
		Return;
	EndIf;
	
	Object = Form.Object;
	
	If Object.Tags.FindRows(New Structure("Tag", Form.Tag)).Count() = 0 Then
		
		Form.LockFormDataForEdit();
		Form.Modified = True;
		
		NewRow = Object.Tags.Add();
		NewRow.Tag = Form.Tag;
		
		Form.UpdateTagsCloud();
		
	EndIf;
	
	Form.Tag = Undefined;
	
EndProcedure

Procedure GenerateFilterOptionTitle(ItemFilterVariant, FiltersInstalled)
	
	PositionStart = Find(ItemFilterVariant.Title, " (");
	If PositionStart <> 0 Then
		ItemFilterVariant.Title = Left(ItemFilterVariant.Title, PositionStart-1);
	EndIf;
	
	If FiltersInstalled <> 0 Then
		ItemFilterVariant.Title = ItemFilterVariant.Title + " (" + FiltersInstalled + ")";
	EndIf;
	
EndProcedure

#EndRegion
