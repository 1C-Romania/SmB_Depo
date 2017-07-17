Function GetPeriodPresentation(ReportParameters, OnlyDates  = False)
	
	TextPeriod = "";
	
	If ReportParameters.Property("Period") Then
		
		If ValueIsFilled(ReportParameters.Period) Then
			TextPeriod = ?(OnlyDates, "", " on ") + Format(ReportParameters.Period, "DLF=D");
		EndIf;
		
	ElsIf ReportParameters.Property("BeginOfPeriod")
		AND ReportParameters.Property("EndOfPeriod") Then
		
		BeginOfPeriod = ReportParameters.BeginOfPeriod;
		EndOfPeriod  = ReportParameters.EndOfPeriod;
		
		If ValueIsFilled(EndOfPeriod) Then 
			If EndOfPeriod >= BeginOfPeriod Then
				TextPeriod = ?(OnlyDates, "", " for ") + PeriodPresentation(BegOfDay(BeginOfPeriod), EndOfDay(EndOfPeriod), "FP = True");
			Else
				TextPeriod = "";
			EndIf;
		ElsIf ValueIsFilled(BeginOfPeriod) AND Not ValueIsFilled(EndOfPeriod) Then
			TextPeriod = ?(OnlyDates, "", " for ") + PeriodPresentation(BegOfDay(BeginOfPeriod), EndOfDay(Date(3999, 11, 11)), "FP = True");
			TextPeriod = StrReplace(TextPeriod, Mid(TextPeriod, Find(TextPeriod, " - ")), " - ...");
		EndIf;
		
	EndIf;
	
	Return TextPeriod;
	
EndFunction

Function GetReportTitleText(ReportParameters)
	
	HeaderText = ReportParameters.Title + GetPeriodPresentation(ReportParameters);
	Return HeaderText;
	
EndFunction

Function GetPeriodicityValue(BeginOfPeriod, EndOfPeriod) Export
	
	Result = Enums.Periodicity.Month;
	If ValueIsFilled(BeginOfPeriod)
		AND ValueIsFilled(EndOfPeriod) Then
		
		Diff = EndOfPeriod - BeginOfPeriod;
		If Diff / 86400 < 45 Then
			Result = Enums.Periodicity.Day;
		Else
			Result = Enums.Periodicity.Month; // Month
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

Procedure OutputReportTitle(ReportParameters, Result) Export
	
	OutputParameters = ReportParameters.ReportSettings.OutputParameters;
	
	OutputParameter = OutputParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If OutputParameter <> Undefined
		AND (NOT OutputParameter.Use OR OutputParameter.Value <> DataCompositionTextOutputType.DontOutput) Then
		OutputParameter.Use = True;
		OutputParameter.Value = DataCompositionTextOutputType.DontOutput; // disable the standard output of a title
	EndIf;
	
	OutputParameter = OutputParameters.FindParameterValue(New DataCompositionParameter("DataParametersOutput"));
	If OutputParameter <> Undefined
		AND (NOT OutputParameter.Use OR OutputParameter.Value <> DataCompositionTextOutputType.DontOutput) Then
		OutputParameter.Use = True;
		OutputParameter.Value = DataCompositionTextOutputType.DontOutput; // disable the parameters standard output
	EndIf;
	
	OutputParameter = OutputParameters.FindParameterValue(New DataCompositionParameter("FilterOutput"));
	If OutputParameter <> Undefined
		AND (NOT OutputParameter.Use OR OutputParameter.Value <> DataCompositionTextOutputType.DontOutput) Then
		OutputParameter.Use = True;
		OutputParameter.Value = DataCompositionTextOutputType.DontOutput; // disable the standard output of a filter
	EndIf;
	
	Template = GetCommonTemplate("StandardReportCommonAreas");
	HeaderArea        = Template.GetArea("HeaderArea");
	SettingsDescriptionField = Template.GetArea("SettingsDescription");
	
	// Title
	If ReportParameters.TitleOutput 
		AND ValueIsFilled(ReportParameters.Title) Then
		HeaderArea.Parameters.ReportHeader = GetReportTitleText(ReportParameters);
		Result.Put(HeaderArea);
		
		// Filter
		TextFilter = "";
		
		If ReportParameters.Property("ParametersToBeIncludedInSelectionText")
			AND TypeOf(ReportParameters.ParametersToBeIncludedInSelectionText) = Type("Array") Then
			
			For Each Parameter IN ReportParameters.ParametersToBeIncludedInSelectionText Do
				If TypeOf(Parameter) <> Type("DataCompositionSettingsParameterValue")
					OR Not Parameter.Use Then
					Continue;
				EndIf;
				TextFilter = TextFilter + ?(IsBlankString(TextFilter), "", NStr("en=' AND ';ru=' И '")) 
					+ TrimAll(Parameter.UserSettingPresentation) + " Equal """ + TrimAll(Parameter.Value) + """";
				
			EndDo;
		EndIf;
		
		For Each FilterItem IN ReportParameters.ReportSettings.Filter.Items Do
			If TypeOf(FilterItem) <> Type("DataCompositionFilterItem")
				OR Not FilterItem.Use
				OR Not ValueIsFilled(FilterItem.UserSettingID)
				OR FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible Then
				Continue;
			EndIf;
			TextFilter = TextFilter + ?(IsBlankString(TextFilter), "", NStr("en=' AND ';ru=' И '")) 
				+ TrimAll(FilterItem.LeftValue) + " " + TrimAll(FilterItem.ComparisonType) + " """ + TrimAll(FilterItem.RightValue) + """";
			
		EndDo;
		
		If Not IsBlankString(TextFilter) Then
			SettingsDescriptionField.Parameters.NameReportSettings      = NStr("en='Filter:';ru='Фильтр:'");
			SettingsDescriptionField.Parameters.DescriptionReportSettings = TextFilter;
			Result.Put(SettingsDescriptionField);
		EndIf;
		
		Result.Area("R1:R" + Result.TableHeight).Name = "Title";
		
	EndIf;
	
EndProcedure

// Procedure sets the calculation formula and dynamic period format.
//
// Parameters:
// 	DataCompositionSchema - DataCompositionSchema - DLS
// 	of the SettingsLinker report - DataCompositionSettings - report settings
//
Procedure CustomizeDynamicPeriod(DataCompositionSchema, ReportParameters, ExpandPeriod = False) Export
	
	ReportSettings = ReportParameters.ReportSettings;
	
	FieldParameter = New DataCompositionParameter("Periodicity");
	ParameterPeriodicity = ReportSettings.DataParameters.FindParameterValue(FieldParameter);
	
	If ParameterPeriodicity <> Undefined
		AND ParameterPeriodicity.Use Then
		
		If Not ValueIsFilled(ParameterPeriodicity.Value)
			OR ParameterPeriodicity.Value = Enums.Periodicity.Auto Then
			ParameterPeriodicity.Value = GetPeriodicityValue(ReportParameters.BeginOfPeriod, ReportParameters.EndOfPeriod);
		EndIf;
		
		SearchField = DataCompositionSchema.CalculatedFields.Find("DynamicPeriod");
		If SearchField <> Undefined Then
			StringDurationPeriod = CommonUse.NameOfEnumValue(ParameterPeriodicity.Value);
			SearchField.Expression = StringDurationPeriod + "Period";
			SearchField.Title = StringDurationPeriod;
			
			AppearanceParameterFormat = SearchField.Appearance.Items.Find("Format");
			AppearanceParameterFormat.Value = FormatStringOfDynamicPeriod(ParameterPeriodicity.Value);
			AppearanceParameterFormat.Use = True;
			
			If ExpandPeriod
				AND ReportParameters.Property("BeginOfPeriod")
				AND ReportParameters.Property("EndOfPeriod") Then
				
				PeriodAddition = DataCompositionPeriodAdditionType[StringDurationPeriod];
				FieldDynamicPeriod = New DataCompositionField("DynamicPeriod");
				Groups = GetGroups(ReportSettings);
				For Each Group IN Groups Do
					If Group.Value.GroupFields.Items.Count() = 1
						AND Group.Value.GroupFields.Items[0].Field = FieldDynamicPeriod Then
						GroupingDynamicPeriod = Group.Value.GroupFields.Items[0];
						GroupingDynamicPeriod.AdditionType = PeriodAddition;
						GroupingDynamicPeriod.BeginOfPeriod = ReportParameters.BeginOfPeriod;
						GroupingDynamicPeriod.EndOfPeriod = ReportParameters.EndOfPeriod;
					EndIf;
				EndDo;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Function FormatStringOfDynamicPeriod(Periodicity) Export
	
	FormatString = "";
	
	If Periodicity = Enums.Periodicity.Day Then
		FormatString = "L=En; DF='dd.MM.yy'";
	ElsIf Periodicity = Enums.Periodicity.Week Then
		FormatString = "L=En; DF='dd.MM.yy'";
	ElsIf Periodicity = Enums.Periodicity.TenDays Then
		FormatString = "L=En; DF='dd.MM.yy'";
	ElsIf Periodicity = Enums.Periodicity.Month Then
		FormatString = "L=En; DF='MMM yy'";
	ElsIf Periodicity = Enums.Periodicity.Quarter Then
		FormatString = "L=En; DF='q ""qtr."" yy'";
	ElsIf Periodicity = Enums.Periodicity.HalfYear Then
		FormatString = "L=En; DF='MM.yy'";
	ElsIf Periodicity = Enums.Periodicity.Year Then
		FormatString = "L=En; DF='yyyy'";
	EndIf;
	
	Return FormatString;
	
EndFunction

Procedure ProcessReportCharts(ReportParameters, ResultDocument) Export
	
	For Each Draw IN ResultDocument.Drawings Do
		// Output labels vertically if the quantity of charts points is more than 6
		Try
			If TypeOf(Draw.Object) = Type("Chart") Then
				
				If ReportParameters.Property("ChartType")
					AND ReportParameters.ChartType <> Undefined
					AND Draw.Object.ChartType <> ReportParameters.ChartType Then
					Draw.Object.ChartType = ReportParameters.ChartType;
				EndIf;
				
				Draw.Object.PlotArea.VerticalMarks  = (Draw.Object.Points.Count() > 6);
				Draw.Object.PlotArea.ValuesScaleFormat = "NG=3,0";
				
				Draw.Object.MeasuringChartValuesScaleSignaturesLocation = GaugeChartValuesScaleLabelsLocation.AtScale;
				Draw.Object.SignaturesMeasuringChartValuesScaleAlongScale = True;
				Draw.Object.MeasuringChartScaleThickness                   = 3;
				Draw.Object.ValuesFormatInSignatures                              = "NFD=2; NG=3,0";
				
			EndIf;
		Except
		EndTry;
	EndDo;
	
EndProcedure

// Procedure sets the size of the picture with a report chart.
//
Procedure SetReportChartSize(Draw) Export

	Draw.Object.ShowTitle = False;
	Draw.Object.LegendArea.Bottom = 0.90;
	Draw.Height = 95;
	Draw.Width = 145;

EndProcedure

Procedure SetReportAppearanceTemplate(ReportSettings) Export
	
	DesignLayoutParameter = GetInputParameter(ReportSettings, "AppearanceTemplate");
	If DesignLayoutParameter <> Undefined
		AND DesignLayoutParameter.Use
		AND ValueIsFilled(DesignLayoutParameter.Value) Then
		Return;
	EndIf;
	
	AppearanceTemplate = "ReportThemeGreen";
	
	SetOutputParameter(ReportSettings, "AppearanceTemplate", AppearanceTemplate);
	
EndProcedure

#Region ReportSettings

// Procedure includes parent groupings in the custom settings if at least one child is enabled
//
// Parameters:
// 	SettingsComposer - DataCompositionSettingsComposer - settings
// 	of the UserSettingsModified report - Boolean - flag of advantages modifications is mandatory to be set. report settings
//
Procedure ChangeGroupsValues(SettingsComposer, UserSettingsModified) Export
	UserSettings = SettingsComposer.UserSettings;
	Settings = SettingsComposer.Settings;
	
	For Each UserSetting IN UserSettings.Items Do
		If (TypeOf(UserSetting) = Type("DataCompositionGroup") 
			Or TypeOf(UserSetting) = Type("DataCompositionTableGroup")
			Or TypeOf(UserSetting) = Type("DataCompositionTable"))
			AND UserSetting.Use Then
			CorrectParentGroupsSettings(UserSetting, UserSettings, Settings, UserSettingsModified);
		EndIf;
	EndDo;
EndProcedure

Procedure CorrectParentGroupsSettings(UserSetting, UserSettings, Settings, UserSettingsModified)
	UserSettingID = UserSetting.UserSettingID;
	
	If Not IsBlankString(UserSettingID) Then
		SettingsObject = GetObjectByUserIdentifier(Settings, UserSettingID);
	Else
		SettingsObject = UserSetting;
	EndIf;
	SettingObjectParent = SettingsObject.Parent;
	
	If TypeOf(SettingObjectParent) = Type("DataCompositionGroup") 
		Or TypeOf(SettingObjectParent) = Type("DataCompositionTableGroup")
		Or TypeOf(SettingObjectParent) = Type("DataCompositionTable") Then
		
		ParentCustomSettingID = SettingObjectParent.UserSettingID;
		
		If Not IsBlankString(ParentCustomSettingID) Then
			CustomSettingParent = FindCustomSetting(UserSettings, ParentCustomSettingID);
			CustomSettingParent.Use = True;
			UserSettingsModified = True;
			
			CorrectParentGroupsSettings(CustomSettingParent, UserSettings, Settings, UserSettingsModified);
		Else
			CorrectParentGroupsSettings(SettingObjectParent, UserSettings, Settings, UserSettingsModified);
		EndIf;
	EndIf;
EndProcedure

// Returns a list of all groupings of the settings linker
// 
// Parameters:
// 	StructureItem - item of DLS setting structure, DLS setting or settings linker ShowTablesGroups - shows that column grouping is added to list (by default, True)
//
Function GetGroups(StructureItem, ShowTableGroups = True) Export
	
	FieldList = New ValueList;
	If TypeOf(StructureItem) = Type("DataCompositionSettingsComposer") Then
		Structure = StructureItem.Settings.Structure;
		AddGroups(Structure, FieldList);
	ElsIf TypeOf(StructureItem) = Type("DataCompositionSettings") Then
		Structure = StructureItem.Structure;
		AddGroups(Structure, FieldList);
	ElsIf TypeOf(StructureItem) = Type("DataCompositionTable") Then
		AddGroups(StructureItem.Rows, FieldList);
		AddGroups(StructureItem.Columns, FieldList);
	ElsIf TypeOf(StructureItem) = Type("DataCompositionChart") Then
		AddGroups(StructureItem.Series, FieldList);
		AddGroups(StructureItem.Points, FieldList);
	Else
		AddGroups(StructureItem.Structure, FieldList, ShowTableGroups);
	EndIf;
	
	Return FieldList;
	
EndFunction

// Adds nested groups of the structure item.
//
Procedure AddGroups(Structure, ListOfGroups, ShowTableGroups = True)
	
	For Each StructureItem IN Structure Do
		If TypeOf(StructureItem) = Type("DataCompositionTable") Then
			AddGroups(StructureItem.Rows, ListOfGroups);
			AddGroups(StructureItem.Columns, ListOfGroups);
		ElsIf TypeOf(StructureItem) = Type("DataCompositionChart") Then
			AddGroups(StructureItem.Series, ListOfGroups);
			AddGroups(StructureItem.Points, ListOfGroups);
		Else
			ListOfGroups.Add(StructureItem);
			If ShowTableGroups Then
				AddGroups(StructureItem.Structure, ListOfGroups);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Finds a common setting by custom setting ID.
//
// Parameters:
//   Settings - DataCompositionSettings - Settings collection.
//   UserSettingID - String -
//
Function GetObjectByUserIdentifier(Settings, UserSettingID, Hierarchy = Undefined) Export
	If Hierarchy <> Undefined Then
		Hierarchy.Add(Settings);
	EndIf;
	
	SettingType = TypeOf(Settings);
	
	If SettingType <> Type("DataCompositionSettings") Then
		
		If Settings.UserSettingID = UserSettingID Then
			
			Return Settings;
			
		ElsIf SettingType = Type("DataCompositionNestedObjectSettings") Then
			
			Return GetObjectByUserIdentifier(Settings.Settings, UserSettingID, Hierarchy);
			
		ElsIf SettingType = Type("DataCompositionTableStructureItemCollection")
			OR SettingType = Type("DataCompositionChartStructureItemCollection")
			OR SettingType = Type("DataCompositionSettingStructureItemCollection") Then
			
			For Each NestedItem IN Settings Do
				SearchResult = GetObjectByUserIdentifier(NestedItem, UserSettingID, Hierarchy);
				If SearchResult <> Undefined Then
					Return SearchResult;
				EndIf;
			EndDo;
			
			If Hierarchy <> Undefined Then
				Hierarchy.Delete(Hierarchy.UBound());
			EndIf;
			
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	If Settings.Selection.UserSettingID = UserSettingID Then
		Return Settings.Selection;
	ElsIf Settings.ConditionalAppearance.UserSettingID = UserSettingID Then
		Return Settings.ConditionalAppearance;
	EndIf;
	
	If SettingType <> Type("DataCompositionTable") AND SettingType <> Type("DataCompositionChart") Then
		If Settings.Filter.UserSettingID = UserSettingID Then
			Return Settings.Filter;
		ElsIf Settings.Order.UserSettingID = UserSettingID Then
			Return Settings.Order;
		EndIf;
	EndIf;
	
	If SettingType = Type("DataCompositionSettings") Then
		SearchResult = FindSettingItem(Settings.DataParameters, UserSettingID);
		If SearchResult <> Undefined Then
			Return SearchResult;
		EndIf;
	EndIf;
	
	If SettingType <> Type("DataCompositionTable") AND SettingType <> Type("DataCompositionChart") Then
		SearchResult = FindSettingItem(Settings.Filter, UserSettingID);
		If SearchResult <> Undefined Then
			Return SearchResult;
		EndIf;
	EndIf;
	
	SearchResult = FindSettingItem(Settings.ConditionalAppearance, UserSettingID);
	If SearchResult <> Undefined Then
		Return SearchResult;
	EndIf;
	
	If SettingType = Type("DataCompositionTable") Then
		
		SearchResult = GetObjectByUserIdentifier(Settings.Rows, UserSettingID, Hierarchy);
		If SearchResult <> Undefined Then
			Return SearchResult;
		EndIf;
		
		SearchResult = GetObjectByUserIdentifier(Settings.Columns, UserSettingID, Hierarchy);
		If SearchResult <> Undefined Then
			Return SearchResult;
		EndIf;
		
	ElsIf SettingType = Type("DataCompositionChart") Then
		
		SearchResult = GetObjectByUserIdentifier(Settings.Points, UserSettingID, Hierarchy);
		If SearchResult <> Undefined Then
			Return SearchResult;
		EndIf;
		
		SearchResult = GetObjectByUserIdentifier(Settings.Series, UserSettingID, Hierarchy);
		If SearchResult <> Undefined Then
			Return SearchResult;
		EndIf;
		
	Else
		
		SearchResult = GetObjectByUserIdentifier(Settings.Structure, UserSettingID, Hierarchy);
		If SearchResult <> Undefined Then
			Return SearchResult;
		EndIf;
		
	EndIf;
	
	If Hierarchy <> Undefined Then
		Hierarchy.Delete(Hierarchy.UBound());
	EndIf;
	
	Return Undefined;
	
EndFunction

Function FindSettingItem(SettingItem, UserSettingID)
	// Search item with the specified UserSettingID (USI) property.
	
	GroupArray = New Array;
	GroupArray.Add(SettingItem.Items);
	
	While GroupArray.Count() > 0 Do
		
		ItemCollection = GroupArray.Get(0);
		GroupArray.Delete(0);
		
		For Each SubordinateItem IN ItemCollection Do
			If TypeOf(SubordinateItem) = Type("DataCompositionSelectedFieldGroup") Then
				// Does not contain IIT; The collection of inserted items does not contain IIT.
			ElsIf TypeOf(SubordinateItem) = Type("DataCompositionParameterValue") Then
				// Does not contain IIT; The collection of inserted items may contain IIT.
				GroupArray.Add(SubordinateItem.NestedParameterValues);
			ElsIf SubordinateItem.UserSettingID = UserSettingID Then
				// Required item is found.
				Return SubordinateItem;
			Else
				// Contains IIT; The collection of inserted items may contain IIT.
				If TypeOf(SubordinateItem) = Type("DataCompositionFilterItemGroup") Then
					GroupArray.Add(SubordinateItem.Items);
				ElsIf TypeOf(SubordinateItem) = Type("DataCompositionSettingsParameterValue") Then
					GroupArray.Add(SubordinateItem.NestedParameterValues);
				EndIf;
			EndIf;
		EndDo;
		
	EndDo;
	
	Return Undefined;
EndFunction

// Finds a custom setting by its identifier.
//
// Parameters:
//   DCUserSettings - DataCompositionUserSettings - Collection of custom settings.
//   ID - String -
//
Function FindCustomSetting(DCUserSettings, ID) Export
	For Each UserSetting IN DCUserSettings.Items Do
		If UserSetting.UserSettingID = ID Then
			Return UserSetting;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

// Gets the settings linker output parameter or DLS setting
//
// Parameters:
// 	SettingsComposerGroup - settings linker or
// 	setting/grouping DLS ParameterName - parameter name DLS
//
Function GetInputParameter(Setting, ParameterName) Export
	
	ParameterArray   = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ParameterName, ".");
	NestingLevel = ParameterArray.Count();
	
	If NestingLevel > 1 Then
		ParameterName = ParameterArray[0];		
	EndIf;
	
	If TypeOf(Setting) = Type("DataCompositionSettingsComposer") Then
		ParameterValue = Setting.Settings.OutputParameters.FindParameterValue(New DataCompositionParameter(ParameterName));
	Else
		ParameterValue = Setting.OutputParameters.FindParameterValue(New DataCompositionParameter(ParameterName));
	EndIf;
	
	If NestingLevel > 1 Then
		For IndexOf = 1 To NestingLevel - 1 Do
			ParameterName = ParameterName + "." + ParameterArray[IndexOf];
			ParameterValue = ParameterValue.NestedParameterValues.Find(ParameterName); 
		EndDo;
	EndIf;
	
	Return ParameterValue;  
	
EndFunction

// Sets the settings linker output parameter or DLS setting
//
// Parameters:
// 	SettingsComposerGroup - settings linker or
// 	setting/grouping DLS ParameterName - parameter name
// 	DLS Value - value of the
// 	output parameter DLS Usage - Shows that the parameter is used. Always equals to True by default.
//
Function SetOutputParameter(Setting, ParameterName, Value, Use = True) Export
	
	ParameterValue = GetInputParameter(Setting, ParameterName);
	
	If ParameterValue <> Undefined Then
		ParameterValue.Use = Use;
		ParameterValue.Value      = Value;
	EndIf;
	
	Return ParameterValue;
	
EndFunction

#EndRegion

