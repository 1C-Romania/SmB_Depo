
#Region ServiceProceduresAndFunctions

Procedure AddError(Errors, ErrorText, ThisIsCriticalError = False, OccurrencePlace = "") Export
	
	ErrorDescription = Errors.Add();
	
	ErrorDescription.ErrorDescription		= ErrorText;
	ErrorDescription.Critical 			= ThisIsCriticalError;
	ErrorDescription.OccurrencePlace	= OccurrencePlace;
	
EndProcedure

Procedure FillInImportFieldsTable(ImportFieldsTable, FillingObjectFullName) Export
	Var Manager;
	
	DataImportFromExternalSourcesOverridable.OverrideDataImportFieldsFilling(ImportFieldsTable, FillingObjectFullName);
	
	If ImportFieldsTable.Count() = 0 Then
		
		DataImportFromExternalSources.GetManagerByFillingObjectName(FillingObjectFullName, Manager);
		Manager.DataImportFieldsFromExternalSource(ImportFieldsTable, FillingObjectFullName);
		
	EndIf;
	
EndProcedure

Procedure OnCreateAtServer(FilledObject, DataLoadSettings, ThisObject, UseFormSSL = True) Export
	
	DataLoadSettings = New Structure;
	
	RunMode = CommonUseReUse.ApplicationRunningMode();
	DataLoadSettings.Insert("UseTogether", DataImportFromExternalSources.UseTogetherWithShippedSSLPart() AND UseFormSSL AND Not RunMode.ThisIsWebClient);
	
	If RunMode.ThisIsWebClient 
		OR Not DataLoadSettings.UseTogether Then
		
		DataImportMethodFromExternalSources= Enums.DataImportMethodFromExternalSources.FileChoice;
		
	Else
	
		DataImportMethodFromExternalSources= SmallBusinessReUse.GetValueOfSetting("DataImportMethodFromExternalSources");
		If Not ValueIsFilled(DataImportMethodFromExternalSources) Then
			
			DataImportMethodFromExternalSources= Enums.DataImportMethodFromExternalSources.FileChoice;
			SmallBusinessServer.SetUserSetting(DataImportMethodFromExternalSources, "DataImportMethodFromExternalSources");
			
		EndIf;
	
	EndIf;
	
	If DataImportMethodFromExternalSources= Enums.DataImportMethodFromExternalSources.Copy Then
		
		DataImportFormNameFromExternalSources = "DataProcessor.DataLoadFromFile.Form.DataLoadFromFile";
		
	ElsIf DataImportMethodFromExternalSources= Enums.DataImportMethodFromExternalSources.FileChoice Then
		
		DataImportFormNameFromExternalSources = "DataProcessor.DataImportFromExternalSources.Form.AssistantFileChoice";
		
	EndIf;
	
	FillingObjectFullName = FilledObject.FullName();
	DataImportFromExternalSourcesOverridable.WhenDeterminingDataImportForm(DataImportFormNameFromExternalSources, FillingObjectFullName, FilledObject);
	
	DataLoadSettings.Insert("FillingObjectFullName", 					FillingObjectFullName);
	DataLoadSettings.Insert("DataImportFormNameFromExternalSources",	DataImportFormNameFromExternalSources);
	
	IsTabularSectionImport = (Find(FillingObjectFullName, "TabularSection") > 0);
	DataLoadSettings.Insert("IsTabularSectionImport", IsTabularSectionImport);
	
	IsCatalogImport = (Find(FillingObjectFullName, "Catalog") > 0);
	DataLoadSettings.Insert("IsCatalogImport", IsCatalogImport);
	
	IsInformationRegisterImport = (Find(FillingObjectFullName, "InformationRegister") > 0);
	DataLoadSettings.Insert("IsInformationRegisterImport", IsInformationRegisterImport);
	
EndProcedure

Procedure ChangeDataImportFromExternalSourcesMethod(DataImportFormNameFromExternalSources) Export
	
	// Change of import method is NOT available in WEB client.
	
	DataImportMethodFromExternalSources= SmallBusinessReUse.GetValueOfSetting("DataImportMethodFromExternalSources");
	If Not ValueIsFilled(DataImportMethodFromExternalSources) Then
		
		DataImportMethodFromExternalSources= Enums.DataImportMethodFromExternalSources.Copy;
		
	EndIf;
	
	CurrentUser = Users.AuthorizedUser();
	If DataImportMethodFromExternalSources= Enums.DataImportMethodFromExternalSources.Copy Then
		
		DataImportMethodFromExternalSources= Enums.DataImportMethodFromExternalSources.FileChoice;
		DataImportFormNameFromExternalSources = "DataProcessor.DataImportFromExternalSources.Form.AssistantFileChoice";
		
	ElsIf DataImportMethodFromExternalSources= Enums.DataImportMethodFromExternalSources.FileChoice Then
		
		DataImportMethodFromExternalSources= Enums.DataImportMethodFromExternalSources.Copy;
		DataImportFormNameFromExternalSources = "DataProcessor.DataLoadFromFile.Form.DataLoadFromFile";
		
	EndIf;
	
	SmallBusinessServer.SetUserSetting(DataImportMethodFromExternalSources, "DataImportMethodFromExternalSources", CurrentUser);
	
EndProcedure

Procedure AddImportDescriptionField(ImportFieldsTable, FieldName, FieldPresentation, FieldType, DerivedValueType, FieldsGroupName = "", Priority = 0, RequiredFilling = False, GroupRequiredFilling = False, Visible = True) Export
	
	NewRow = ImportFieldsTable.Add();
	
	NewRow.FieldName = FieldName;
	NewRow.FieldPresentation = FieldPresentation;
	NewRow.FieldType = FieldType;
	NewRow.DerivedValueType = DerivedValueType;
	NewRow.FieldsGroupName = FieldsGroupName;
	NewRow.Priority = Priority;
	NewRow.RequiredFilling = RequiredFilling;
	NewRow.GroupRequiredFilling = GroupRequiredFilling;
	NewRow.Visible = Visible;
	
EndProcedure

Procedure CreateFieldsAndGroupsTree(GroupsAndFields)
	
	GroupsAndFields = New ValueTree;
	GroupsAndFields.Columns.Add("FieldsGroupName", New TypeDescription("String"));
	GroupsAndFields.Columns.Add("IncomingDataType");
	GroupsAndFields.Columns.Add("DerivedValueType");
	GroupsAndFields.Columns.Add("FieldName", New TypeDescription("String"));
	GroupsAndFields.Columns.Add("FieldPresentation", New TypeDescription("String"));
	GroupsAndFields.Columns.Add("ColumnNumber", New TypeDescription("Number"));
	GroupsAndFields.Columns.Add("RequiredFilling", New TypeDescription("Boolean"));
	GroupsAndFields.Columns.Add("GroupRequiredFilling", New TypeDescription("Boolean"));
	GroupsAndFields.Columns.Add("Visible", New TypeDescription("Boolean"));
	
EndProcedure

Procedure CreateImportDescriptionFieldsTable(ImportFieldsTable) Export
	
	ImportFieldsTable = New ValueTable;
	ImportFieldsTable.Columns.Add("FieldName");
	ImportFieldsTable.Columns.Add("FieldPresentation");
	ImportFieldsTable.Columns.Add("FieldType"); 					// Incoming data type
	ImportFieldsTable.Columns.Add("DerivedValueType");	// Data type in the application
	ImportFieldsTable.Columns.Add("FieldsGroupName");
	ImportFieldsTable.Columns.Add("Priority");
	ImportFieldsTable.Columns.Add("RequiredFilling");
	ImportFieldsTable.Columns.Add("GroupRequiredFilling");
	ImportFieldsTable.Columns.Add("Visible");
	
EndProcedure

Procedure CreateErrorsDescriptionTable(Errors) Export
	
	Errors = New ValueTable;
	
	Errors.Columns.Add("ErrorDescription",		New TypeDescription("String"));
	Errors.Columns.Add("Critical", 			New TypeDescription("Boolean"));
	Errors.Columns.Add("OccurrencePlace",	New TypeDescription("String"));
	
EndProcedure

Procedure GetManagerByFillingObjectName(FillingObjectFullName, Manager) Export
	
	Manager = CommonUse.ObjectManagerByFullName(FillingObjectFullName);
	
EndProcedure

Procedure AddServiceFields(ImportFieldsTable, ServiceFieldsGroup, FillingObjectFullName, ThisIsImportToTP) Export
	
	// Mandatory service field. Used by assistant.
	ServiceField						= ServiceFieldsGroup.Rows.Add(); 
	ServiceField.FieldName				= ServiceFieldNameImportToApplicationPossible();
	ServiceField.DerivedValueType= New TypeDescription("Boolean");
	
	If Not ThisIsImportToTP Then
		
		ServiceField						= ServiceFieldsGroup.Rows.Add(); 
		ServiceField.FieldName				= "_RowMatched";
		ServiceField.DerivedValueType= New TypeDescription("Boolean");
		
	EndIf;
	
	// Possibility to describe custom service fields
	DataImportFromExternalSourcesOverridable.WhenAddingServiceFields(ServiceFieldsGroup, FillingObjectFullName);
	
EndProcedure

Procedure FillInGroupAndFieldsTree(ImportFieldsTable, GroupsAndFields, FillingObjectFullName, ThisIsImportToTP)
	
	FieldGroupsTable = ImportFieldsTable.Copy(,"FieldsGroupName");
	FieldGroupsTable.GroupBy("FieldsGroupName");
	
	TableRow = FieldGroupsTable.Add();
	TableRow.FieldsGroupName = DataImportFromExternalSources.FieldsMandatoryForFillingGroupName();
	
	TableRow = FieldGroupsTable.Add();
	TableRow.FieldsGroupName = DataImportFromExternalSources.FieldsGroupMandatoryForFillingName();
	
	TableRow = FieldGroupsTable.Add();
	TableRow.FieldsGroupName = DataImportFromExternalSources.FieldsGroupNameService();
	
	For Each TableRow IN FieldGroupsTable Do
		
		If IsBlankString(TableRow.FieldsGroupName) Then
			
			// Fields are not united in groups and decomposed separately by property RequiredFilling
			Continue;
			
		EndIf;
		
		NewFirstLevelRow= GroupsAndFields.Rows.Add();
		NewFirstLevelRow.FieldsGroupName = TableRow.FieldsGroupName;
		
		FilterParameters = New Structure;
		FilterParameters.Insert("FieldsGroupName", TableRow.FieldsGroupName);
		If TableRow.FieldsGroupName = DataImportFromExternalSources.FieldsMandatoryForFillingGroupName() Then
			
			FilterParameters.Insert("FieldsGroupName", "");
			FilterParameters.Insert("RequiredFilling", True);
			
		ElsIf TableRow.FieldsGroupName = DataImportFromExternalSources.FieldsGroupMandatoryForFillingName() Then
			
			FilterParameters.Insert("FieldsGroupName", "");
			FilterParameters.Insert("RequiredFilling", False);
			
		ElsIf TableRow.FieldsGroupName = DataImportFromExternalSources.FieldsGroupNameService() Then
			
			DataImportFromExternalSources.AddServiceFields(ImportFieldsTable, NewFirstLevelRow, FillingObjectFullName, ThisIsImportToTP);
			Continue;
			
		EndIf;
		
		GroupRequiredFilling = False;
		RowArray 			= ImportFieldsTable.FindRows(FilterParameters);
		If RowArray.Count() > 0 Then
			
			IsCustomFieldsGroup = DataImportFromExternalSources.IsCustomFieldsGroup(TableRow.FieldsGroupName);
			If IsCustomFieldsGroup Then
				
				NewFirstLevelRow.DerivedValueType = RowArray[0].DerivedValueType; // type of a derived value is the same in all fields of one fields group (reference, string, number, etc.)
				NewFirstLevelRow.Visible = False;
				
			EndIf;
			
			For Each ArrayRow IN RowArray Do
				
				NewSecondLevelRow = NewFirstLevelRow.Rows.Add();
				NewSecondLevelRow.FieldName = ArrayRow.FieldName;
				NewSecondLevelRow.IncomingDataType = ArrayRow.FieldType; // incoming data type (string, number)
				NewSecondLevelRow.DerivedValueType = ArrayRow.DerivedValueType;
				NewSecondLevelRow.FieldPresentation = ArrayRow.FieldPresentation;
				NewSecondLevelRow.RequiredFilling = ArrayRow.RequiredFilling;
				NewSecondLevelRow.GroupRequiredFilling = ArrayRow.GroupRequiredFilling;
				NewSecondLevelRow.Visible = ArrayRow.Visible;
				
				If NewSecondLevelRow.Visible Then
					
					NewFirstLevelRow.Visible = True;
					
				EndIf;
				
				GroupRequiredFilling = GroupRequiredFilling OR ArrayRow.GroupRequiredFilling;
				
			EndDo;
			
		EndIf;
		
		NewFirstLevelRow.GroupRequiredFilling = GroupRequiredFilling;
		
	EndDo;
	
EndProcedure

Procedure CreateAndFillGroupAndFieldsByObjectNameTree(FillingObjectFullName, GroupsAndFields, ThisIsImportToTP = False) Export
	Var ImportFieldsTable;
	
	CreateImportDescriptionFieldsTable(ImportFieldsTable);
	FillInImportFieldsTable(ImportFieldsTable, FillingObjectFullName);
	CreateFieldsAndGroupsTree(GroupsAndFields);
	FillInGroupAndFieldsTree(ImportFieldsTable, GroupsAndFields, FillingObjectFullName, ThisIsImportToTP);
	
EndProcedure

Procedure FillColumnNumbersInMandatoryFieldsAndGroupsTree(GroupsAndFields, SpreadsheetDocument) Export
	
	SelectedFields = New Array;
	
	Header = SpreadsheetDocument.GetArea("R1");
	For ColumnNumber = 1 To Header.TableWidth Do
		
		CellWithBreakdown = Header.GetArea(1, ColumnNumber, 1, ColumnNumber);
		FieldName = CellWithBreakdown.CurrentArea.DetailsParameter;
		
		If Not IsBlankString(FieldName) Then
			
			RowArray = GroupsAndFields.Rows.FindRows(New Structure("FieldName", FieldName), True);
			If RowArray.Count() > 0 Then
				
				RowArray[0].ColumnNumber = ColumnNumber;
				SelectedFields.Add(FieldName); // Remember that this field is already selected.
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DeleteUnselectedFieldsInGroupsMadatoryForFilling(GroupsAndFields) Export
	
	For Each FieldsGroup IN GroupsAndFields.Rows Do
		
		If FieldsGroup.FieldsGroupName = "_FieldsGroupMandatoryForFilling" Then // do not clear fields mandatory for filling
			
			Continue;
			
		EndIf;
		
		RecordsLeftToHandle = FieldsGroup.Rows.Count();
		While RecordsLeftToHandle <> 0 Do
			
			FieldsGroupField = FieldsGroup.Rows.Get(RecordsLeftToHandle - 1);
			If FieldsGroupField.ColumnNumber = 0 Then
				
				FieldsGroup.Rows.Delete(FieldsGroupField);
				
			EndIf;
			
			RecordsLeftToHandle = RecordsLeftToHandle - 1;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function IsCustomFieldsGroup(FieldsGroupName) Export
	
	Return (FieldsGroupName <> FieldsMandatoryForFillingGroupName() AND FieldsGroupName <> FieldsGroupMandatoryForFillingName() AND FieldsGroupName <> FieldsGroupNameService());
	
EndFunction

Function ServiceFieldNameImportToApplicationPossible() Export
	
	Return "_ImportToApplicationPossible";
	
EndFunction

Function FieldsMandatoryForFillingGroupName() Export
	
	Return "_FieldsGroupMandatoryForFilling";
	
EndFunction

Function FieldsGroupMandatoryForFillingName() Export
	
	Return "_FieldsGroupOptionalForFilling";
	
EndFunction

Function FieldsGroupNameService() Export
	
	Return "_ServiceFieldsGroup";
	
EndFunction

Function PostFixInputDataFieldNames() Export
	
	Return "_IncomingData";
	
EndFunction

Function UseTogetherWithShippedSSLPart() Export
	
	UseTogether = True;
	DataImportFromExternalSourcesOverridable.WhenDeterminingUsageMode(UseTogether);
	
	Return UseTogether;
	
EndFunction


//:::DataImport

// Taken from StringFunctionsClientServer.DecomposeStringToWordsArray
//
// Its own procedure is used because of error parsing string:
// Works and services;;Designing of air-conditioning and ventilation systems;
// where second and fourth parameter will be skipped instead of filling in an empty value.
//
Function DecomposeStringIntoSubstringsArray(Val String, Delimiter) Export
	
	Substrings = New Array;
	
	TextSize = StrLen(String);
	SubstringBeginning = 1;
	For Position = 1 To TextSize Do
		
		CharCode = CharCode(String, Position);
		If StringFunctionsClientServer.IsWordSeparator(CharCode, Delimiter) Then
			
			If Position <> SubstringBeginning Then
				
				Substrings.Add(Mid(String, SubstringBeginning, Position - SubstringBeginning));
				
			ElsIf Position = SubstringBeginning Then
				
				Substrings.Add("");
				
			EndIf;
			
			SubstringBeginning = Position + 1;
			
		EndIf;
		
	EndDo;
	
	If Position <> SubstringBeginning Then
		
		Substrings.Add(Mid(String, SubstringBeginning, Position - SubstringBeginning));
		
	ElsIf Position = SubstringBeginning Then
		
		Substrings.Add("");
		
	EndIf;
	
	Return Substrings;
	
EndFunction

Procedure ImportCSVFileToTabularDocument(TempFileName, SpreadsheetDocument)
	
	File = New File(TempFileName);
	If Not File.Exist() Then 
		
		Return;
		
	EndIf;
	
	Template = DataProcessors.DataImportFromExternalSources.GetTemplate("SimpleTemplate");
	AreaValue = Template.GetArea("Value");
	
	TextReader = New TextReader(TempFileName, TextEncoding.ANSI);
	String = TextReader.ReadLine();
	While String <> Undefined Do
		
		FirstColumn = True;
		SubstringArray = DecomposeStringIntoSubstringsArray(String, ";");
		For Each Substring IN SubstringArray Do
			
			AreaValue.Parameters.Value = String(Substring);
			
			If FirstColumn Then
				
				SpreadsheetDocument.Put(AreaValue);
				FirstColumn = False;
				
			else
				
				SpreadsheetDocument.Join(AreaValue);
				
			EndIf;
			
		EndDo;
		
		String = TextReader.ReadLine();
		
	EndDo;
	
EndProcedure

Procedure ImportData(ServerCallParameters, TemporaryStorageAddress) Export
	
	TempFileName 		= ServerCallParameters.TempFileName;
	Extension 				= ServerCallParameters.Extension;
	SpreadsheetDocument 		= ServerCallParameters.SpreadsheetDocument;
	FillingObjectFullName = ServerCallParameters.FillingObjectFullName;
	
	If Extension = "xlsx" Then 
		
		DataProcessors.DataImportFromExternalSources.ImportExcel2007FormatData(TempFileName, SpreadsheetDocument, FillingObjectFullName);
		
	ElsIf Extension = "csv" Then 
		
		ImportCSVFileToTabularDocument(TempFileName, SpreadsheetDocument);
		FillInDetailsInTabularDocument(SpreadsheetDocument, SpreadsheetDocument.TableWidth, FillingObjectFullName)
		
	Else
		
		SpreadsheetDocument.Read(TempFileName);
		FillInDetailsInTabularDocument(SpreadsheetDocument, SpreadsheetDocument.TableWidth, FillingObjectFullName)
		
	EndIf;
	
	TemporaryStorageAddress = PutToTempStorage(SpreadsheetDocument, TemporaryStorageAddress);
	
EndProcedure

Function ConvertDataToColumnType(Value, ColumnType)
	
	Result = Value;
	
	For Each Type IN ColumnType.Types() Do
		
		If Type = Type("Date") Then
			
			If StrLen(Value) < 11 Then
				Value = Mid(Value, 7, 4) + Mid(Value,4,2) + Left(Value, 2);
			Else
				Value = Mid(Value, 7, 4) + Mid(Value,4,2) + Left(Value, 2); 
			EndIf;
				
			TargetType = New TypeDescription("Date");
			Result = TargetType.AdjustValue(Value);
			
		ElsIf Type = Type("Number") Then
			TargetType = New TypeDescription("Number");
			Result = TargetType.AdjustValue(Value);
		EndIf;
	
	EndDo;
	
	Return Result;

EndFunction

Procedure DataFromValuesTableToTabularDocument(DataFromFile, SpreadsheetDocument, FillingObjectFullName) Export 
	
	ColumnsCount = DataFromFile.Columns.Count();
	If ColumnsCount < 1 Then
		
		Return;
		
	EndIf;
	
	SpreadsheetDocument.Clear();
	
	Template = DataProcessors.DataImportFromExternalSources.GetTemplate("SimpleTemplate");
	AreaValue = Template.GetArea("Value");
	
	For RowIndex = 0 To DataFromFile.Count() - 1 Do
		
		VTRow = DataFromFile.Get(RowIndex);
		For ColumnIndex = 0 to ColumnsCount - 1 Do
			
			AreaValue.Parameters.Value = ConvertDataToColumnType(VTRow[ColumnIndex], DataFromFile.Columns.Get(ColumnIndex).ValueType);
			
			If ColumnIndex = 0 Then
				
				SpreadsheetDocument.Put(AreaValue);
				
			else
				
				SpreadsheetDocument.Join(AreaValue);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	FillInDetailsInTabularDocument(SpreadsheetDocument, ColumnsCount, FillingObjectFullName);
	
EndProcedure

Procedure FillInDetailsInTabularDocument(SpreadsheetDocument, ColumnsCount, FillingObjectFullName) Export
	Var ImportFieldsTable;
	
	If Number(ColumnsCount) < 1 Then
		
		Return;
		
	EndIf;
	
	DataImportFromExternalSources.CreateImportDescriptionFieldsTable(ImportFieldsTable);
	DataImportFromExternalSources.FillInImportFieldsTable(ImportFieldsTable, FillingObjectFullName);
	
	Details = New ValueList;
	Details.Add("Not to import", "Not to import");
	For Each TableRow IN ImportFieldsTable Do
	
		Details.Add(TableRow.FieldName, TableRow.FieldPresentation);
		
	EndDo;
	
	Template = DataProcessors.DataImportFromExternalSources.GetTemplate("SimpleTemplate");
	HeaderArea = Template.GetArea("Title");
	
	For ColumnNumber = 1 To ColumnsCount Do
		
		DestinationArea = SpreadsheetDocument.Area(1, ColumnNumber, 1, ColumnNumber);
		SpreadsheetDocument.InsertArea(HeaderArea.Areas.Title, DestinationArea, SpreadsheetDocumentShiftType.WithoutShift, True);
		
		DestinationArea.Text 				= "Not to import";
		DestinationArea.DetailsParameter	= "";
		DestinationArea.Details			= Details;
		
		AreaColumn = SpreadsheetDocument.Area(, ColumnNumber, , ColumnNumber);
		AreaColumn.ColumnWidth = 22.75;
		
	EndDo;
	
EndProcedure

#EndRegion