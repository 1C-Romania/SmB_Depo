////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR SETTINGS MANAGING MECHANICS

Function FillSettingsOnReportOpening(ReportObject) Export
	
	If ValueIsFilled(ReportObject.SavedSetting) Then
		Return True; 
	EndIf;	
		
	//Users = UsersManaging.GroupListUserIncluding();
	Users = New Array;
	Users.Add(SessionParameters.CurrentUser);
	Users.Add(Catalogs.UsersGroups.AllUsers);
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	SavedSettings.Ref AS SavedSetting,
	|	CASE
	|		WHEN SavedSettings.Owner = &CurrentUser
	|			THEN 1
	|		ELSE 0
	|	END AS Priority
	|FROM
	|	Catalog.SavedSettings AS SavedSettings
	|WHERE
	|	SavedSettings.Owner IN (&CurrentUser, &AllUsers)
	|	AND SavedSettings.UseOnOpen = TRUE
	|	AND SavedSettings.SetupObject = &SetupObject
	|
	|ORDER BY
	|	Priority DESC";
	
	Query.SetParameter("CurrentUser", SessionParameters.CurrentUser);
	Query.SetParameter("AllUsers", Catalogs.UsersGroups.AllUsers);
	Query.SetParameter("SetupObject", "ReportObject." + ReportObject.Metadata().Name);
	TableResult = Query.Execute().Unload();
	
	If TableResult.Count() > 0 Then
		ReportObject.SavedSetting = TableResult[0].SavedSetting;
		ReportObject.ApplySetting();
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

#If Client Then
	
// Procedure opens settings of form choice form
//
// Parameters:
//  OwnerForm            - Form - form, which is owner of choice form.
//  SetupObject       - Object, for which choosing setting.
//  SettingSavingMode - True - form is open for choosing saving setting.
//
Procedure SelectFormSetting(SavedSetting, OwnerForm, SetupObject, SettingSavingMode) Export

	ChoiceForm = Catalogs.SavedSettings.GetChoiceForm(, OwnerForm);
	
	ChoiceForm.Filter.SetupObject.Set(SetupObject);
	
	If Find(SetupObject, "ReportObject") > 0 Then
		ChoiceForm.Filter.SettingType.Set(Enums.SettingsTypes.ReportSettings);
	EndIf;
	
	ChoiceForm.Filter.SetupObject.Set(SetupObject);
	
	ChoiceForm.CurrentLineParameter    = SavedSetting;
	
	ChoiceForm.SettingSavingMode = SettingSavingMode;
	
	If NOT (IsInRole(Metadata.Roles.Role_SystemSettings) OR IsInRole(Metadata.Roles.Right_Administration_ConfigurationAdministration) OR NOT ChoiceForm.SettingSavingMode) Then
	
		ChoiceForm.Controls.CatalogListSavedSettings.Columns.Owner.Visible = False;
		
	EndIf;	
	
	ChoiceForm.DoModal();

EndProcedure

// Procedure save form settings.
//
// Parameters:
//  SavedSetting       - CatalogRef.SavedSettings - saving setting.
//  SavingSettings - parameters form setting.
//
Procedure SaveObjectSetting(SavedSetting, SavingSettings) Export

	ObjectSavedSetting = SavedSetting.GetObject();
	
	If ObjectSavedSetting.SettingsStorage.Get() <> Undefined Then
		
		Answer = DoQueryBox(NStr("en = 'Do you want to overwrite existing settings?'; pl = 'Czy chcesz nadpisać istniejące ustawienia?'"), QuestionDialogMode.OKCancel);
		If Answer = DialogReturnCode.Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	ObjectSavedSetting.SettingsStorage = New ValueStorage(SavingSettings);
	
	Try
		ObjectSavedSetting.Write();
	Except
		Alerts.AddAlert(Nstr("en='Form setting was not write';pl='Ustawinie formatki nie zostało zapisane'")+":" + Chars.LF + "- " + ErrorDescription());
	EndTry;

EndProcedure

// Returns list filter settings as table
//
// Parameters:
//  Filter - (Filter) - filter, by which will be builded table
//
// Returning value:
//  (ValueTable) - table with filter values
//
Function GetListFilterSetting(Filter) Export

	// Save filter settings
	SettingsTable = New ValueTable();

	SettingsTable.Columns.Add("FilterName");
	SettingsTable.Columns.Add("Use");
	SettingsTable.Columns.Add("ComparisonType");
	SettingsTable.Columns.Add("Value");
	SettingsTable.Columns.Add("ValueFrom");
	SettingsTable.Columns.Add("ValueTo");

	For Each FilterItem In Filter Do
		ParametersString = SettingsTable.Add();

		ParametersString.FilterName     = FilterItem.Name;
		ParametersString.Use = FilterItem.Use;
		ParametersString.ComparisonType  = FilterItem.ComparisonType;
		ParametersString.Value      = FilterItem.Value;
		ParametersString.ValueFrom     = FilterItem.ValueFrom;
		ParametersString.ValueTo    = FilterItem.ValueTo;
	EndDo;

	Return SettingsTable;

EndFunction

// Return list order settings as table
//
// Parameters:
//  Order - (Order) - Order, by which will be builded table
//
// Return value:
//  (ValueTable) - table with order values
//
Function GetListOrderSetting(Order) Export

	// Save order settings
	SettingsTable = New ValueTable();

	SettingsTable.Columns.Add("Data");
	SettingsTable.Columns.Add("Direction");

	For Each OrderingItem In Order Do
		ParametersString = SettingsTable.Add();

		ParametersString.Data      = OrderingItem.Data;
		ParametersString.Direction = OrderingItem.Direction;
	EndDo;

	Return SettingsTable;

EndFunction

// Returns list columns settings as table
//
// Parameters:
//  Columns - (Columns) - list columns, by which will be builded table
//
// Return value:
//  (ValueTable) - table with settings
//
Function GetListColumnsSetting(Columns) Export

	
	SettingsTable = New ValueTable();

	SettingsTable.Columns.Add("ColumnName");
	SettingsTable.Columns.Add("Visible");
	SettingsTable.Columns.Add("Location");
	SettingsTable.Columns.Add("SizeChange");
	SettingsTable.Columns.Add("Width");
	SettingsTable.Columns.Add("CellHeight");
	SettingsTable.Columns.Add("AutoCellHeight");

	For Each Column In Columns Do
		ParametersString = SettingsTable.Add();

		ParametersString.ColumnName       = Column.Name;
		ParametersString.Visible        = Column.Visible;
		ParametersString.Location        = Column.Location;
		ParametersString.SizeChange = Column.SizeChange;
		ParametersString.Width           = Column.Width;
		ParametersString.CellHeight     = Column.CellHeight;
		ParametersString.AutoCellHeight = Column.AutoCellHeight;
	EndDo;

	Return SettingsTable;

EndFunction
 
// Set list filter settings by saved values from table
//
// Parameters:
//  SettingsStructure - Structure - applying settings structure.
//  ValueKey      - String - key of applying setting.
//  Filter             - (Filter) - Form filter settings
//
Procedure ApplyListFilterSetting(SettingsStructure, ValueKey, Filter) Export
	
	Var SettingsTable;
	
	If TypeOf(SettingsStructure) = Type("Structure") Then
		SettingsStructure.Property(ValueKey, SettingsTable);
	EndIf;
	
	If SettingsTable = Undefined Then
		Return;
	EndIf;
	
	For Each FilterItem In Filter Do
		TableRow = SettingsTable.Find(FilterItem.Name , "FilterName");
		
		If TableRow = Undefined Then
			Continue;
		EndIf;
		
		SetNewValue(FilterItem.Use, TableRow.Use);
		If FilterItem.ValueType.ContainsType(Type("String")) AND FilterItem.ValueType.StringQualifiers.Length = 0 Then
			If TableRow.ComparisonType = ComparisonType.NotEqual or TableRow.ComparisonType = ComparisonType.NotContains Then
				SetNewValue(FilterItem.ComparisonType,  ComparisonType.NotContains);
			Else
				SetNewValue(FilterItem.ComparisonType,  ComparisonType.Contains);
			EndIf;
		Else
			SetNewValue(FilterItem.ComparisonType,  TableRow.ComparisonType);
		EndIf;
		
		If TypeOf(FilterItem.Value) = Type("ValueList") Then
			If TypeOf(TableRow.Value) = Type("ValueList") AND TableRow.Value.ValueType = FilterItem.ValueType Then
				FilterItem.Value = TableRow.Value;
			EndIf;
		Else
			SetNewValue(FilterItem.Value, FilterItem.ValueType.AdjustValue(TableRow.Value));
		EndIf;
		
		SetNewValue(FilterItem.ValueFrom,  FilterItem.ValueType.AdjustValue(TableRow.ValueFrom));
		SetNewValue(FilterItem.ValueTo, FilterItem.ValueType.AdjustValue(TableRow.ValueTo));
	EndDo;
	
EndProcedure

Procedure ApplyListOrderSetting(SettingsStructure, ValueKey, Order, OrderSetting) Export

	Var SettingsTable;
	
	If TypeOf(SettingsStructure) = Type("Structure") Then
		SettingsStructure.Property(ValueKey, SettingsTable);
	EndIf;

	If SettingsTable = Undefined Then
		Return;
	EndIf;

	OrderString = "";

	For each TableRow In SettingsTable Do
		If OrderSetting.Find(TableRow.Data) = Undefined Then
			Continue;
		EndIf;

		OrderString = OrderString + TableRow.Data;
		
		If TableRow.Direction = SortDirection.Desc Then
			OrderString = OrderString + " Desc";
		EndIf;
		
		OrderString = OrderString + ",";
	EndDo;

	OrderString = Left(OrderString, StrLen(OrderString) - 1);

	If OrderString <> "" Then
		Order.Set(OrderString);
	EndIf;

EndProcedure


Procedure ApplyListColumnsSetting(SettingsStructure, ValueKey, Columns) Export

	Var SettingsTable;
	
	If TypeOf(SettingsStructure) = Type("Structure") Then
		SettingsStructure.Property(ValueKey, SettingsTable);
	EndIf;

	If SettingsTable = Undefined Then
		Return;
	EndIf;

	For each TableRow In SettingsTable Do
		Column = Columns.Find(TableRow.ColumnName);
		
		If Column = Undefined Then
			Continue;
		EndIf;
		
		Columns.Move(Column, SettingsTable.Indexof(TableRow) - Columns.Indexof(Column));
		
		Column.Visible        = TableRow.Visible;
		Column.Location        = TableRow.Location;
		Column.SizeChange = ColumnSizeChange.Change; // need to apply width changes
		Column.Width           = TableRow.Width;
		Column.SizeChange = TableRow.SizeChange;
		Column.CellHeight     = TableRow.CellHeight;
		Column.AutoCellHeight = TableRow.AutoCellHeight;
	EndDo;

EndProcedure

// Read value settings from settings structure and apply it to receiver, 
// performing all necessery checkings
//
// Parameters:
//  SettingsStructure - Structure - structure of applying setting.
//  ValueKey      - String - key of applying setting.
//  ReceiverValue  - to this parameter will be stored setting value.
//  ValueType       - String - type, which should have value setting
//
Procedure ApplySavedSettingItem(SettingsStructure, ValueKey, ReceiverValue, ValueType) Export
	
	Var Value;
	
	If TypeOf(SettingsStructure) = Type("Structure") Then
		SettingsStructure.Property(ValueKey, Value);
	EndIf;
	 	
	// Value
	//If TypeOf(ValueType) = Type("TypeDescription") AND ValueType.ContainsType(TypeOf(Value))
	// OR TypeOf(Value) = Type(ValueType) Then
		ReceiverValue = Value;
	//EndIf;
	
EndProcedure

// Open form by form setting.
//
// Parameters:
//  SavedSetting - CatalogRef.SavedSettings- opening settings.
//
Procedure OpenFormSetting(SavedSetting) Export
	
	SetupObject = SavedSetting.SetupObject;
	
	If SavedSetting.IsFolder Then
		Return;
	                                        
	Else
		
		OpenValueForm(SetupObject,SavedSetting);
		Return;
		
	EndIf;
	
	//Form.SavedSetting = SavedSetting;
	//
	//Form.ApplySetting();
	//
	//Form.Open();
	
EndProcedure

Function OpenValueForm(GUIDOrRef,SavedSetting) Export

	Try
		If TypeOf(GUIDOrRef) = Type("String") Then
			Ref = ValueFromStringInternal(GUIDOrRef);
		Else
			Ref = GUIDOrRef;
		EndIf;
		
		OpenValue(Ref);
		
	Except
		
		Try
			GUIDRes = New(Type(GUIDOrRef));
			If Metadata.Reports.Contains(GUIDRes.Metadata()) Then
				NewReport = GUIDRes;
				NewReport.SavedSetting = SavedSetting;
				NewReport.ApplySetting();
				NewReportsForm = NewReport.GetForm();
				NewReportsForm.IsDetailProcessing = False;
				NewReportsForm.Open();
				NewReportsForm.RefreshReport();
			Else
			OpenValue(New(Type(GUIDOrRef)));
			EndIf;
		
		Except
			Return False;
		EndTry; 
		
	EndTry;
	
	Return True;
	
EndFunction

Procedure SetNewValue(Parameter, Value) Export

	If Parameter <> Value Then
		Parameter = Value;
	EndIf;

EndProcedure

// Checks, modification of specified Object attributes.
// Need to set Cancel in checks before Object write.
//
// Parameters:
//  Object    - Object for check.
//  Attributes - String - list of attributes Name for checking (comma separated).
//  Cancel     - True if attribute was changed.
//
Procedure CancelOnChangeAttributes(Object, Val Attributes, Cancel) Export
	
	If IsBlankString(Attributes) Then
		Return;
		
	ElsIf Object.Ref.Isempty() Then
		Cancel = True;
		Return;
	EndIf;
	
	PropertiesStructure = New Structure(Attributes);
	
	For each StructureItem In PropertiesStructure Do
		AttributeName = StructureItem.Key;
		
		If Object[AttributeName] <> Object.Ref[AttributeName] Then
			Cancel = True;
			Return;
		EndIf;
	EndDo;
	
EndProcedure

Procedure SetupListKind(TableBox, User) Export
	
	TableBox.SelectionMode         = TableBoxSelectionMode.Multiline;
	
EndProcedure

Procedure SetFilterAvailability(TableBox, Val MandatoryFilters = "") Export
	
	MandatoryFilters = Upper(MandatoryFilters) + ", ";

	For each FilterItemControl In TableBox.FilterSettings Do
		MandatoryFilter = Find(MandatoryFilters, Upper(FilterItemControl.Name)) > 0;
		
		FilterItemControl.Enabled = NOT MandatoryFilter;
	EndDo;

EndProcedure

Procedure SetOrderAvailability(TableBox, Enabled = True) Export

	For each OrderingItemControl In TableBox.OrderSetting Do
		OrderingItemControl.Enabled = Enabled;
	EndDo;

EndProcedure

Procedure SaveReportGeneralParameters(ReportObject, Part = "") Export
	
	GeneralParameters = ReportObject.GetReportParametersStructure(False, True, False);
	
	RestoredValue = RestoreValue("GeneralSettings" + Part);
	
	If TypeOf(RestoredValue) <> Type("Structure") Then
		RestoredValue = New Structure;
	EndIf;
	For each GeneralParameter In GeneralParameters Do
		RestoredValue.Insert(GeneralParameter.Key, GeneralParameter.Value);
	EndDo;
	
	SaveValue("GeneralSettings" + Part, RestoredValue);
	
EndProcedure

Procedure FillReportsGeneralSettings(ThisObject, User, Part = "") Export
	
	ParametersStructure = New Structure;
	
	// 1. Fill period settings 
	DateStart    = CommonAtServer.GetUserSettingsValue("ReportsGeneralStartDate",User);
	ParametersStructure.Insert("DateStart", DateStart);
	ParametersStructure.Insert("DateEnd", CurrentDate());
	
	// 2. Fill overall settings
	RestoredValue = RestoreValue("GeneralSettings" + Part);
	If TypeOf(RestoredValue) = Type("Structure") Then
		For each Item In RestoredValue Do
			ParametersStructure.Insert(Item.Key, Item.Value);
		EndDo;
	EndIf;
	
	// 3. Apply period period and overall settings
	ThisObject.ApplyReportParametersStructure(ParametersStructure, True, True, False);
	
EndProcedure

Procedure RestoreGeneralParameters(Object, GeneralParametersStructure, Prefix) Export
	
	For each Parameter In GeneralParametersStructure Do
		
		Value = RestoreValue(Prefix + "_" + Parameter.Key);
		If ValueIsFilled(Value) Then
			GeneralParametersStructure.Insert(Parameter.Key, Value);
			Object[Parameter.Key] = Value;
		EndIf;
		
	EndDo;
		
EndProcedure

Procedure OpenOnStart() Export
	
	

EndProcedure

#EndIf

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS WORKING WITH USER'S SETTINGS

Procedure SaveUserValue(ObjectName, ValueName, Value, User = Undefined) Export
	
	If User = Undefined Then
		User = SessionParameters.CurrentUser;
	EndIf;
	
	RecordManager = InformationRegisters.UsersSavedValues.CreateRecordManager();
	RecordManager.User = User;
	RecordManager.ObjectName = ObjectName;
	RecordManager.ValueName = ValueName;
	RecordManager.Value = New ValueStorage(Value, New Deflation);
	RecordManager.Write();
	
EndProcedure

Function GetUserValue(ObjectName, ValueName, User = Undefined) Export
	
	If User = Undefined Then
		User = SessionParameters.CurrentUser;
	EndIf;
	
	RecordManager = InformationRegisters.UsersSavedValues.CreateRecordManager();
	RecordManager.User = User;
	RecordManager.ObjectName = ObjectName;
	RecordManager.ValueName = ValueName;
	RecordManager.Read();
	
	If RecordManager.Selected() Then
		Return RecordManager.Value.Get();
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Procedure DeleteUserValue(ObjectName, ValueName, User = Undefined) Export
	
	If User = Undefined Then
		User = SessionParameters.CurrentUser;
	EndIf;
	
	RecordManager = InformationRegisters.UsersSavedValues.CreateRecordManager();
	RecordManager.User = User;
	RecordManager.ObjectName = ObjectName;
	RecordManager.ValueName = ValueName;
	RecordManager.Read();
	
	If RecordManager.Selected() Then
		RecordManager.Delete();
	EndIf;	
	
EndProcedure	