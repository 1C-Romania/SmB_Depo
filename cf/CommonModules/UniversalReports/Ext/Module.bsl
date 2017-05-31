
// Function save report attributes in structure. Data  can be restored by procedure RestoreReportsAttributes().
// Used for given attributes during interpretation
// By default saved all attributes including tabular parts
// If attributes list is given, then exception list is ignored
// Data saved with key "_ReportsAttributes", value - structure 

Function SaveReportAttributes(ReportObject, StructSetting = Undefined, Val PageSave = "", Val PageDoesNotSave = "") Export
	
	StructParameters = ?(StructSetting = Undefined, New Structure, StructSetting);
	
	MetaReport = ReportObject.Metadata();
	If IsBlankString(PageSave) Then
	
		StructData = New Structure;
		ExceptionsStructure = ?(IsBlankString(PageDoesNotSave), New Structure, New Structure(PageDoesNotSave));
		
		MetaReports    = Metadata.Reports;
		MetaDataProcessor = Metadata.Dataprocessors;
		For Each MetaAttr In MetaReport.Attributes Do
		
			If ExceptionsStructure.Property(MetaAttr.Name) Then
				Continue; 
			EndIf;
			
			AttrTypes = ReportObject.Metadata().Attributes[MetaAttr.Name].Type.Types();
			If AttrTypes.Count() = 1 Then
			
				// Exclude attributes with type Report and DataProcessor (for example Universal report)
				MetaFindByType = Metadata.FindByType(AttrTypes[0]);
				If NOT MetaFindByType = Undefined  
				     AND (MetaReports.Contains(MetaFindByType) OR MetaDataProcessor.Contains(MetaFindByType)) Then
					Continue; 
				EndIf;
				
				
				StructData.Insert(MetaAttr.Name, ReportObject[MetaAttr.Name]);
				
			Else 
			
				StructData.Insert(MetaAttr.Name, ReportObject[MetaAttr.Name]);
				
			EndIf;
			
		EndDo;
		
		
		For Each MetaAttr In MetaReport.TabularSections Do
		
			If ExceptionsStructure.Property(MetaAttr.Name) Then
				Continue; 
			EndIf;
			
			StructData.Insert(MetaAttr.Name, ReportObject[MetaAttr.Name].Unload());
			
		EndDo;
		
	Else 
	
		StructData = New Structure(PageSave);
		For Each CurrentAttr In StructData Do
		
			If MetaReport.Attributes.Find(CurrentAttr.Key) <> Undefined Then
				StructData.Insert(CurrentAttr.Key, ReportObject[CurrentAttr.Key]);
			ElsIf MetaReport.TabularSections.Find(CurrentAttr.Key) <> Undefined Then
				StructData.Insert(CurrentAttr.Key, ReportObject[CurrentAttr.Key].Unload());
			EndIf;
			
		EndDo;
		
	EndIf;
	
	StructParameters.Insert("_ReportsAttributes", StructData);
	
	Return StructParameters;

EndFunction // SaveReportAttributes()


Procedure RestoreReportAttributes(ReportObject, StructSetting) Export
	
	If TypeOf(StructSetting) <> Type("Structure")
	 OR NOT StructSetting.Property("_ReportsAttributes") Then
		Return;
	EndIf;
	
	MetaReport = ReportObject.Metadata();
	For Each SavedAttr In StructSetting["_ReportsAttributes"] Do
		If MetaReport.Attributes.Find(SavedAttr.Key) <> Undefined Then
			ReportObject[SavedAttr.Key] = SavedAttr.Value;
		ElsIf MetaReport.TabularSections.Find(SavedAttr.Key) <> Undefined Then
			ReportObject[SavedAttr.Key].Load(SavedAttr.Value);
		EndIf;
	EndDo;

EndProcedure // RestoreReportAttributes()



////////////////////////////////////////////////////////////////////////////////
// ADDITIONAL GLOBAL PROCEDURES AND FUNCTIONS FOR UNIVERSAL REPORT //

Function TypeEmptyValue(GivenType) Export
	
	Return EmptyValueType(GivenType);
	
EndFunction // TypeEmptyValue();

Function GetDefaultValues(User, Settings) Export
	
	Return CommonAtServer.GetUserSettingsValue(Settings, User);
	
EndFunction // GetDefaultValues()

Procedure SelectProperty(Control, Property, SettingForm, StandardProcessing) Export
	
	// Procedure need for correct syntax control
	
EndProcedure // SelectProperty()


Procedure SelectCategory(Control, Assigment, SettingForm, StandardProcessing) Export
	
	// Procedure need for correct syntax control
	
EndProcedure // SelectCategory()



////////////////////////////////////////////////////////////////////////////////////////////////////
// PROCEDURES WORK WITH HEADERFOOTER


Function GetHeaderFooterSettings()

	//Settings = Constants.HeaderFooterSettingsByDefault.Get().Get();
	//
	//If TypeOf(Settings) <> Type("Structure") Then
		
		
		Settings = New Structure;
		
		Top = New Structure;
		Bottom = New Structure;
		
		Top.Insert("Enabled", False);
		Top.Insert("StartPage", 1);
		Top.Insert("LeftText",   "");
		Top.Insert("CenterText", "");
		Top.Insert("RightText",  "");
		
		Bottom.Insert("Enabled", False);
		Bottom.Insert("StartPage", 1);
		Bottom.Insert("LeftText",   "");
		Bottom.Insert("CenterText", "");
		Bottom.Insert("RightText",  "");
		
		Settings.Insert("Header", Top);
		Settings.Insert("Footer",  Bottom);
		
	//Else
	//
	//	If Not Settings.Property("Header") Then
	//		
	//		Top = New Structure;
	//		
	//		Top.Insert("Enabled", False);
	//		Top.Insert("StartPage", 1);
	//		Top.Insert("LeftText",   "");
	//		Top.Insert("CenterText", "");
	//		Top.Insert("RightText",  "");
	//		
	//		Settings.Insert("Header", Top);
	//		
	//	EndIf;
	//	
	//	If Not Settings.Property("Footer") Then
	//		
	//		Bottom = New Structure;
	//		
	//		Bottom.Insert("Enabled", False);
	//		Bottom.Insert("StartPage", 1);
	//		Bottom.Insert("LeftText",   "");
	//		Bottom.Insert("CenterText", "");
	//		Bottom.Insert("RightText",  "");
	//		
	//		Settings.Insert("Footer",  Bottom);
	//		
	//	EndIf;
	//	
	//EndIf;
	
	Return Settings;

EndFunction // GetHeaderFooterSettings()




Procedure SetDefaultHeaderFooter(SpreadsheetDocument, ReportName, User) Export

	Settings = GetHeaderFooterSettings();
	
	SpreadsheetDocument.Header.Enabled          = Settings.Header.Enabled;
	SpreadsheetDocument.Header.StartPage = Settings.Header.StartPage;
	SpreadsheetDocument.Header.VerticalAlign = VerticalAlign.Bottom;
	SpreadsheetDocument.Header.LeftText   = FillHeaderFooterText(Settings.Header.LeftText, ReportName, User);
	SpreadsheetDocument.Header.CenterText = FillHeaderFooterText(Settings.Header.CenterText, ReportName, User);
	SpreadsheetDocument.Header.RightText  = FillHeaderFooterText(Settings.Header.RightText, ReportName, User);
	
	SpreadsheetDocument.Footer.Enabled          = Settings.Footer.Enabled;
	SpreadsheetDocument.Footer.StartPage = Settings.Footer.StartPage;
	SpreadsheetDocument.Footer.VerticalAlign = VerticalAlign.Top;
	SpreadsheetDocument.Footer.LeftText   = FillHeaderFooterText(Settings.Footer.LeftText, ReportName, User);
	SpreadsheetDocument.Footer.CenterText = FillHeaderFooterText(Settings.Footer.CenterText, ReportName, User);
	SpreadsheetDocument.Footer.RightText  = FillHeaderFooterText(Settings.Footer.RightText, ReportName, User);
	
EndProcedure // SetHeaderFooter()


Function FillHeaderFooterText(Text, ReportName, User)

	Result = Text;
	
	Result = StrReplace(Result, "[&ReportName]", ReportName);
	Result = StrReplace(Result, "[&User]", User);
	
	Return Result;

EndFunction // FillHeaderFooterText()



////////////////////////////////////////////////////////////////////////////////////////////////////
// PROCEDURES REPORT INTERFACES


Procedure ProcessFilterFieldsOnUniversalReportGeneralForm(Controls, ReportBuilder, ControlsWithDataConnectionStructure = Undefined, PathToBuilder = "ReportObject") Export


	ControlsWithDataConnectionStructure = New Structure;

	FiltersCount = 0;
	For Cnt = 0 To ReportBuilder.Filter.Count()-1 Do

		FilterField = ReportBuilder.Filter[Cnt];

		If NOT (IsBlankString(FilterField.Name) Or FilterField.Name = "Periodicity") Then
		
			FiltersCount=FiltersCount+1;
		
		EndIf; 
	EndDo;
	If FiltersCount>5 Then
		FiltersCount = 5;
	EndIf;

	Cnt = 0;
	For Index = 0 To ReportBuilder.Filter.Count()-1 Do

		FilterField = ReportBuilder.Filter[Index];

		If IsBlankString(FilterField.Name) Or FilterField.Name = "Periodicity" Then
		
			Continue;
		
		EndIf; 

		Cnt = Cnt + 1;
		If Cnt>FiltersCount Then
			break;
		EndIf;
		Checkbox = Controls["SettingCheckBox"+Cnt];
		
		ComboBox = Controls["ComparisonTypeField"+Cnt];

//			ComboBox.SetAction("OnChange", EthalonComboBox.GetAction("OnChange"));
		
		TextBox = Controls["CustomField"+Cnt];

//			TextBox.SetAction("OnChange", EthalonTextBox.GetAction("OnChange"));

		TextBoxFrom = Controls["CustomFieldFrom"+Cnt];

//			TextBoxFrom.SetAction("OnChange", EthalonTextBoxFrom.GetAction("OnChange"));
		
		TextBoxTo = Controls["CustomFieldTo"+Cnt];;
//			TextBoxTo.SetAction("OnChange", EthalonTextBoxTo.GetAction("OnChange"));

		FilterType = ReportBuilder.Filter[FilterField.Name].ValueType;

		ComboBox.ChoiceList = GetComparisonTypeListByTypes(FilterType);

		Controls["SettingCheckBox"+Cnt].Caption = FilterField.Presentation;
		Controls["SettingCheckBox"+Cnt].Data   = PathToBuilder+".ReportBuilder.Filter."+FilterField.Name+".Use";
		Controls["ComparisonTypeField"+Cnt].Data = PathToBuilder+".ReportBuilder.Filter."+FilterField.Name+".ComparisonType";
		Controls["CustomField"+Cnt].Data     = PathToBuilder+".ReportBuilder.Filter."+FilterField.Name+".Value";
		Controls["CustomFieldFrom"+Cnt].Data    = PathToBuilder+".ReportBuilder.Filter."+FilterField.Name+".ValueFrom";
		Controls["CustomFieldTo"+Cnt].Data   = PathToBuilder+".ReportBuilder.Filter."+FilterField.Name+".ValueTo";

		ControlsWithDataConnectionStructure.Insert("SettingCheckBox"+Cnt,   PathToBuilder+".ReportBuilder.Filter."+FilterField.Name+".Use");
		ControlsWithDataConnectionStructure.Insert("ComparisonTypeField"+Cnt, PathToBuilder+".ReportBuilder.Filter."+FilterField.Name+".ComparisonType");
		ControlsWithDataConnectionStructure.Insert("CustomField"+Cnt,     PathToBuilder+".ReportBuilder.Filter."+FilterField.Name+".Value");
		ControlsWithDataConnectionStructure.Insert("CustomFieldFrom"+Cnt,    PathToBuilder+".ReportBuilder.Filter."+FilterField.Name+".ValueFrom");
		ControlsWithDataConnectionStructure.Insert("CustomFieldTo"+Cnt,   PathToBuilder+".ReportBuilder.Filter."+FilterField.Name+".ValueTo");

		
		Controls["CustomField"+Cnt].ChooseType   = NOT (FilterType.Types().Count()=1);
		Controls["CustomFieldFrom"+Cnt].ChooseType  = NOT (FilterType.Types().Count()=1);
		Controls["CustomFieldTo"+Cnt].ChooseType = NOT (FilterType.Types().Count()=1);

		If Controls["ComparisonTypeField"+Cnt].Value = ComparisonType.Interval
			Or Controls["ComparisonTypeField"+Cnt].Value = ComparisonType.IntervalIncludingBounds 
			Or Controls["ComparisonTypeField"+Cnt].Value = ComparisonType.IntervalIncludingLowerBound 
			Or Controls["ComparisonTypeField"+Cnt].Value = ComparisonType.IntervalIncludingUpperBound Then
		
			Controls["CustomField"+Cnt].Visible = False;
			Controls["CustomFieldFrom"+Cnt].Visible = True;
			Controls["CustomFieldTo"+Cnt].Visible = True;
		
		Else
		
			Controls["CustomField"+Cnt].Visible = True;
			Controls["CustomFieldFrom"+Cnt].Visible = False;
			Controls["CustomFieldTo"+Cnt].Visible = False;
		
		EndIf;
	
	EndDo; 

EndProcedure


Procedure CustomFieldOnChange(Control, Filter, ControlAndDataConnectionStructure=Undefined) Export

	Pos = Find(Control.Name, "CustomField");
	If Pos>0 Then
		
		If TypeOf(ControlAndDataConnectionStructure)= Type("Structure") Then
			
			
			DataPath="";
			If ControlAndDataConnectionStructure.Property(Control.Name, DataPath) Then
				
				DataPath = Mid(DataPath, Find(DataPath, "Filter.")+StrLen("Filter."));
				FieldName = Left(DataPath, Find(DataPath, ".")-1);
				
			EndIf;
		Else
			FieldName = Mid(Control.Name, StrLen("CustomField")+1);
		EndIf;
		
		ValueMetadata = Metadata.FindByType(TypeOf(Control.Value));
		If ValueMetadata <> Undefined Then
			If Metadata.Catalogs.Find(ValueMetadata.Name) <> Undefined Then
				If Control.Value.IsFolder Then
					Filter[FieldName].ComparisonType = ComparisonType.InHierarchy;
				EndIf;
			EndIf;
		Else
			If Control.ValueType.Types().Count() = 2 Then
				EmptyList = New ValueList;
				If Control.ValueType.ContainsType(Type("ValueList")) Then
					TypeNotList = ?(Control.ValueType.Types()[0] = Type("ValueList"), Control.ValueType.Types()[1], Control.ValueType.Types()[0]);
					
					If ValueIsNotFilled(Control.Value) Or (TypeOf(Control.Value) = Type("ValueList") And Control.Value.Count() = 0) Then
						If (Filter[FieldName].ComparisonType = ComparisonType.InList)
							Or (Filter[FieldName].ComparisonType = ComparisonType.InListByHierarchy)
							Or (Filter[FieldName].ComparisonType = ComparisonType.NotInList)
							Or (Filter[FieldName].ComparisonType = ComparisonType.NotInListByHierarchy) Then
							ArrayWithType = New array(1);
							
							ArrayWithType[0] = TypeNotList;
							
							EmptyList.ValueType = New TypeDescription(ArrayWithType);
							
							Control.Value = EmptyList;
						Else
							Control.Value = EmptyValueType(TypeNotList);
						EndIf;
					EndIf;
				EndIf;
			EndIf;
		EndIf;

		If NOT (ValueIsNotFilled(Control.Value) Or (TypeOf(Control.Value) = Type("ValueList") And Control.Value.Count() = 0)) Then
			Filter[FieldName].Use = True;
		EndIf;
		
	EndIf;

EndProcedure


Procedure CustomFieldFromOnChange(Control, Filter, ControlAndDataConnectionStructure=Undefined) Export

	Pos = Find(Control.Name, "CustomFieldFrom");
	If Pos>0 Then
		
		If TypeOf(ControlAndDataConnectionStructure)= Type("Structure") Then
			
			
			DataPath="";
			If ControlAndDataConnectionStructure.Property(Control.Name, DataPath) Then
				
				DataPath = Mid(DataPath, Find(DataPath, "Filter.")+StrLen("Filter."));
				FieldName = Left(DataPath, Find(DataPath, ".")-1);
				
			EndIf;
		Else
			FieldName = Mid(Control.Name, StrLen("CustomFieldFrom")+1);
		EndIf;

		If ValueIsFilled(Control.Value) Then
			Filter[FieldName].Use = True;
		EndIf;
		
	EndIf;

EndProcedure


Procedure CustomFieldToOnChange(Control, Filter, ControlAndDataConnectionStructure=Undefined) Export

	Pos = Find(Control.Name, "CustomFieldTo");
	If Pos>0 Then
		
		If TypeOf(ControlAndDataConnectionStructure)= Type("Structure") Then
			
			
			DataPath="";
			If ControlAndDataConnectionStructure.Property(Control.Name, DataPath) Then
				
				DataPath = Mid(DataPath, Find(DataPath, "Filter.")+StrLen("Filter."));
				FieldName = Left(DataPath, Find(DataPath, ".")-1);
				
			EndIf;
		Else
			FieldName = Mid(Control.Name, StrLen("CustomFieldTo")+1);
		EndIf;

		If ValueIsFilled(Control.Value) Then
			Filter[FieldName].Use = True;
		EndIf;
		
	EndIf;
	
EndProcedure


Procedure ComparisonTypeFieldOnChange(Control, Controls) Export

	FilterName = Mid(Control.Name, Find(Control.Name, "ComparisonTypeField")+StrLen("ComparisonTypeField"));
	
	// 
		If Control.Value = ComparisonType.Interval
			Or Control.Value = ComparisonType.IntervalIncludingBounds 
			Or Control.Value = ComparisonType.IntervalIncludingLowerBound 
			Or Control.Value = ComparisonType.IntervalIncludingUpperBound Then
		
			If Controls.Find("CustomField" + FilterName) <> UNDEFINED Then
				Controls["CustomField"+FilterName].Visible = False;
			EndIf;
			If Controls.Find("CustomFieldFrom" + FilterName) <> UNDEFINED Then
				Controls["CustomFieldFrom"+FilterName].Visible = True;
			EndIf;
			If Controls.Find("CustomFieldTo" + FilterName) <> UNDEFINED Then
				Controls["CustomFieldTo"+FilterName].Visible = True;
			EndIf;
		
		Else
		
			If Controls.Find("CustomField" + FilterName) <> UNDEFINED Then
				CustomField = Controls["CustomField"+FilterName];
				CustomField.Visible = True;
				If Control.Value = ComparisonType.InList
					Or Control.Value = ComparisonType.NotInList
					Or Control.Value = ComparisonType.InListByHierarchy
					Or Control.Value = ComparisonType.NotInListByHierarchy Then
					CustomField.TypeRestriction = New TypeDescription("ValueList");
				Else
					CustomField.TypeRestriction = New TypeDescription(CustomField.ValueType,, "ValueList");
				EndIf;
			EndIf;
			If Controls.Find("CustomFieldFrom" + FilterName) <> UNDEFINED Then
				Controls["CustomFieldFrom"+FilterName].Visible = False;
			EndIf;
			If Controls.Find("CustomFieldTo" + FilterName) <> UNDEFINED Then
				Controls["CustomFieldTo"+FilterName].Visible = False;
			EndIf;
		
		EndIf;

EndProcedure


Function GetAccumulationRegistersList() Export

	BalanceRegistersList = New ValueList;

	For Each MetadataRegister In Metadata.AccumulationRegisters Do
		
		If NOT AccessRight("Read", MetadataRegister) Then
			Continue;
		EndIf;

		BalanceRegistersList.Add(MetadataRegister.Name, MetadataRegister.Presentation());

	EndDo;
	
	Return BalanceRegistersList;
	
Endfunction // GetBalanceRegistersList()


Function GetBalanceRegistersList() Export

	BalanceRegistersList = New ValueList;

	For Each MetadataRegister In Metadata.AccumulationRegisters Do
		
		If NOT AccessRight("Read", MetadataRegister) Then
			Continue;
		EndIf;

		If MetadataRegister.RegisterType = Metadata.ObjectProperties.accumulationregistertype.Balance Then

			BalanceRegistersList.Add(MetadataRegister.Name, MetadataRegister.Presentation());

		EndIf;

	EndDo;
	
	Return BalanceRegistersList;
	
Endfunction // GetBalanceRegistersList()

Function InListDoesnotSetMarks(CurrentList) Export
	
	For CurrentIndex = 0 To CurrentList.Count()- 1 Do
		CurrentValue = CurrentList.Get(CurrentIndex);
		If CurrentValue.Check Then
			Return False;
		EndIf;
	EndDo;
	Return True;

EndFunction


Function GetComparisonTypeListByTypes(TypeDescr) Export
	
	AvaliableValuesTable = New ValueTable;
	AvaliableValuesTable.Columns.Add("ComparisonType");
	AvaliableValuesTable.Columns.Add("NumberKind");
	
	For each TypeDescription In TypeDescr.Types() Do
	
		NewTableRow = AvaliableValuesTable.Add();
		NewTableRow.ComparisonType = ComparisonType.Equal;
		NewTableRow.NumberKind = 1;
		
		NewTableRow = AvaliableValuesTable.Add();
		NewTableRow.ComparisonType = ComparisonType.NotEqual;
		NewTableRow.NumberKind = 1;
		
		NewTableRow = AvaliableValuesTable.Add();
		NewTableRow.ComparisonType = ComparisonType.InList;
		NewTableRow.NumberKind = 1;
		
		NewTableRow = AvaliableValuesTable.Add();
		NewTableRow.ComparisonType = ComparisonType.NotInList;
		NewTableRow.NumberKind = 1;

		If Catalogs.AllRefsType().ContainsType(TypeDescription) And Metadata.FindByType(TypeDescription).Hierarchical Then
			
			NewTableRow = AvaliableValuesTable.Add();
			NewTableRow.ComparisonType = ComparisonType.InListByHierarchy;
			NewTableRow.NumberKind = 1;
			
			NewTableRow = AvaliableValuesTable.Add();
			NewTableRow.ComparisonType = ComparisonType.NotInListByHierarchy;
			NewTableRow.NumberKind = 1;
			
			NewTableRow = AvaliableValuesTable.Add();
			NewTableRow.ComparisonType = ComparisonType.InHierarchy;
			NewTableRow.NumberKind = 1;
			
			NewTableRow = AvaliableValuesTable.Add();
			NewTableRow.ComparisonType = ComparisonType.NotInHierarchy;
			NewTableRow.NumberKind = 1;
			
		ElsIf TypeDescription = Type("Number")
			  Or TypeDescription = Type("String")
			  Or TypeDescription = Type("Date") Then
			
			NewTableRow = AvaliableValuesTable.Add();
			NewTableRow.ComparisonType = ComparisonType.Greater;
			NewTableRow.NumberKind = 1;
			
			NewTableRow = AvaliableValuesTable.Add();
			NewTableRow.ComparisonType = ComparisonType.GreaterOrEqual;
			NewTableRow.NumberKind = 1;
			
			NewTableRow = AvaliableValuesTable.Add();
			NewTableRow.ComparisonType = ComparisonType.Less;
			NewTableRow.NumberKind = 1;
			
			NewTableRow = AvaliableValuesTable.Add();
			NewTableRow.ComparisonType = ComparisonType.LessOrEqual;
			NewTableRow.NumberKind = 1;
			
			NewTableRow = AvaliableValuesTable.Add();
			NewTableRow.ComparisonType = ComparisonType.Interval;
			NewTableRow.NumberKind = 1;
			
			NewTableRow = AvaliableValuesTable.Add();
			NewTableRow.ComparisonType = ComparisonType.IntervalIncludingBounds;
			NewTableRow.NumberKind = 1;
			
			NewTableRow = AvaliableValuesTable.Add();
			NewTableRow.ComparisonType = ComparisonType.IntervalIncludingLowerBound;
			NewTableRow.NumberKind = 1;
			
			NewTableRow = AvaliableValuesTable.Add();
			NewTableRow.ComparisonType = ComparisonType.IntervalIncludingUpperBound;
			NewTableRow.NumberKind = 1;
			
		EndIf;
		
		If TypeDescription = Type("String") Then
			NewTableRow = AvaliableValuesTable.Add();
			NewTableRow.ComparisonType = ComparisonType.Contains;
			NewTableRow.NumberKind = 1;
		EndIf;
		
	EndDo;
	
	AvaliableValuesTable.Groupby("ComparisonType", "NumberKind");
	
	ComparisonTypesList = New ValueList;
	TypesCount = TypeDescr.Types().Count();
	
	For each TableRow In AvaliableValuesTable Do
		If TableRow.NumberKind = TypesCount Then
			ComparisonTypesList.Add(TableRow.ComparisonType);
		EndIf; 
	EndDo; 
	
	Return ComparisonTypesList;
	
Endfunction // GetBalanceRegistersList()

