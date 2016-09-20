////////////////////////////////////////////////////////////////////////////////
// Subsystem "Reports variants" (server).
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// Generates sections list to which commands of reports panel call are placed.
//
// Returns:
//   ValueTable - Sections info.
//       * Ref        - CatalogRef.MetadataObjectIDs
//       * Metadata    - MetadataObject.
//       * Name           - String.
//       * Presentation - String.
//
Function UsedSections() Export
	Result = New ValueTable;
	Result.Columns.Add("Ref",          New TypeDescription("CatalogRef.MetadataObjectIDs"));
	Result.Columns.Add("Metadata",      New TypeDescription("MetadataObject"));
	Result.Columns.Add("Name",             TypeDescriptionString());
	Result.Columns.Add("Presentation",   TypeDescriptionString());
	Result.Columns.Add("PanelTitle", TypeDescriptionString());
	
	SectionList = New ValueList;
	
	ReportsVariantsOverridable.DetermineSectionsWithReportVariants(SectionList);
	
	If CommonUse.SubsystemExists("StandardSubsystems.ApplicationSettings") Then
		ProcessorModuleAdministrationPanelSSL = CommonUse.CommonModule("DataProcessors.AdministrationPanelSSL");
		ProcessorModuleAdministrationPanelSSL.OnDefiningSectionsWithSectionOptions(SectionList);
	EndIf;
	
	For Each ItemOfList IN SectionList Do
		SectionMetadata = ItemOfList.Value;
		If ValueIsFilled(ItemOfList.Presentation) Then
			CaptionPattern = ItemOfList.Presentation;
		Else
			CaptionPattern = NStr("en='Reports section ""%1""';ru='Отчеты раздела ""%1""'");
		EndIf;
		
		String = Result.Add();
		String.Ref          = CommonUse.MetadataObjectID(SectionMetadata);
		String.Metadata      = SectionMetadata;
		String.Name             = SectionMetadata.Name;
		String.Presentation   = SectionMetadata.Presentation();
		String.PanelTitle = StrReplace(CaptionPattern, "%1", String.Presentation);
	EndDo;
	
	Return Result;
EndFunction

// Receives report variant reference by key attributes set.
//
// Parameters:
//   Report        - Corresponds to the catalog attribute - Full name or report reference.
//   VariantKey - Corresponds to the catalog attribute - Report variant name.
//
// Returns: 
//   * CatalogRef.ReportsVariants - When a variant is found.
//   * Undefined                     - When variant is not found.
//
Function GetRef(Report, VariantKey) Export
	Result = Undefined;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	ReportsVariants.Ref
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariants
	|WHERE
	|	ReportsVariants.Report = &Report
	|	AND ReportsVariants.VariantKey = &VariantKey";
	Query.SetParameter("Report", Report);
	Query.SetParameter("VariantKey", VariantKey);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Result = Selection.Ref;
	EndIf;
	
	Return Result;
EndFunction

// Generates reports array available to the current user.
//
// Returns:
//   Array - Reports references are available for the current user.
//       Values types correspond to the Catalog report attribute type of the ReportsVariants catalog.
//
// Definition:
//   This array should be used in all queries
//   to the "ReportsVariants" catalog table as filter
//   by the "Report" attribute not including cases when variants are selected from the external sources.
//
Function CurrentUserReports() Export
	
	AvailableReports = ReportsVariantsReUse.AvailableReports();
	
	// Add references to additional reports available to the current user to the array.
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnAddAdditionalReportsAvailableToCurrentUser(AvailableReports);
	EndIf;
	
	Return AvailableReports;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Support of overridable modules.

// Calls the report manager module to fill in its settings.
//   For use in ReportsVariantsOverridable.SetReportsVariants().
//  See ConfigurationReportsVariantsSettingsTree() function description.
//	//
// Parameters:
//   Settings - Collection - Passed "as it is" from the SetReportsVariants procedure.
//   ReportMetadata - MetadataObject - Metadata report.
//	//
// IMPORTANT:
//   To use it, in the report manager module export procedure should be placed according to the template.:
// // Placement settings in the report panel.
//	//
// // Parameters:
// //   Settings - Collection - Used for the reports settings description
//        and va//riants See description to ReportsVariants.ConfigurationReportVariantsSettingTree().
//    ReportSettings - ValueTreeRow - Placement settings of all report variants.
//  //     See "Attributes for change" of the ReportsVariants function.ConfigurationReportVariantsSetupTree().
//	//
// // Definition:
// //  See ReportsVariantsOverridable.SetReportsVariants().
//	//
// // Auxiliary methods:
// //   VariantSettings = ReportsVariants.VariantDesc(Settings, ReportSettings, "<VariantName>");
// //   ReportsVariants.SetOutputModeInReportPanels(Settings, ReportSettings, True/False);
//	//
// Procedure SetReportVariants(Settings, ReportSettings)
// 	Export VariantSettings = ModuleReportsVariants.VariantDescription(Settings, ReportSettings, "<VariantName>");
// 	VariantSettings.Definition = NStr("en='<Definition>';ru='<Описание>'");
// EndProcedure
//
Procedure SetReportInManagerModule(Settings, ReportMetadata) Export
	ReportSettings = ReportDescription(Settings, ReportMetadata);
	Reports[ReportMetadata.Name].ConfigureReportsVariants(Settings, ReportSettings);
EndProcedure

// Finds settings of the specified report. It is used for placing setting and report general parameters.
//   For use in ReportsVariantsOverridable.SetReportsVariants().
//  See ConfigurationReportsVariantsSettingsTree() function description.
//
// Parameters:
//   OptionsTree - ValueTree - Used to describe settings of reports and variants.
//      See ConfigurationReportsVariantsSettingsTree() function description.
//   ReportValueOrMetadata - MetadataObject, CatalogRef.MetadataObjectsIDs -
//       Metadata or report reference.
//
// Returns:
//   ValueTreeRow - Report.
//      See "Attributes for change" of the ConfigurationReportsVariantsSettingsTree() function.
//
Function ReportDescription(OptionsTree, ReportValueOrMetadata) Export
	IsMetadata = (TypeOf(ReportValueOrMetadata) = Type("MetadataObject"));
	If IsMetadata Then
		RowReport = OptionsTree.Rows.Find(ReportValueOrMetadata, "Metadata", False);
	Else
		RowReport = OptionsTree.Rows.Find(ReportValueOrMetadata, "Report", False);
	EndIf;
	
	If RowReport = Undefined Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred while
		|receiving report description ""%1"", it is not connected to subsystem ""%2""';ru='Ошибка получения
		|описания отчета ""%1"", он не подключен к подсистеме ""%2""'"),
			String(ReportValueOrMetadata),
			ReportsVariantsClientServer.SubsystemDescription(""));
	EndIf;
	
	Return RowReport;
EndFunction

// Finds settings of the report variant. Used for placement setting.
//   For use in ReportsVariantsOverridable.SetReportsVariants().
//
// Parameters:
//   OptionsTree - ValueTree - Used to describe reports and
//       variants settings see ConfigurationReportsVariantsSettingsTree() function description.
//   ReportTreeRowOrValueOrMetadata - TreeRow,
//       MetadataObject, CatalogRef.MetadataObjectIDs - Settings description, metadata or report reference.
//   VariantKey - String - Report variant name as it is specified in the data layout schema.
//
// Returns: 
//   ValueTreeRow - Variant.
//      See "Attributes for change" of the ConfigurationReportsVariantsSettingsTree() function.
//
Function VariantDesc(OptionsTree, ReportTreeRowOrValueOrMetadata, VariantKey) Export
	If TypeOf(ReportTreeRowOrValueOrMetadata) = Type("ValueTreeRow") Then
		RowReport = ReportTreeRowOrValueOrMetadata;
	Else
		RowReport = ReportDescription(OptionsTree, ReportTreeRowOrValueOrMetadata);
	EndIf;
	
	If VariantKey = "" Then
		RowOption = RowReport.DefaultVariant;
	Else
		RowOption = RowReport.Rows.Find(VariantKey, "VariantKey", False);
	EndIf;
	
	If RowOption = Undefined Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Variant ""%1"" is not found for report ""%2"".';ru='Вариант ""%1"" не найден для отчета ""%2"".'"),
			VariantKey,
			RowReport.Metadata.Name);
	EndIf;
	
	FillDetailsRowsOption(RowOption, RowReport);
	
	Return RowOption;
EndFunction

// Sets the output mode of the Reports and Variants in reports panels.
//
// Parameters:
//   Settings - Passed "as it is" from the SetReportsVariants procedure.
//   ReportOrSubsystem - ValueTreeRow, MetadataObject: Report, MetadataObject: Subsystem -
//       Description of report or subsystem for which the output mode is set.
//       When subsystem is passed, the mode is set recursively for all reports from its content.
//   OutputReportsInsteadVariants - Boolean, String - Output mode of this report hyperlinks in the reports panel:
//       - True, "ByReports" - Default report variants are hidden and the report (variant with an empty key) is enabled and seen.
//       - False, "ByVariants" - Report variants are visible by default and report is disabled. As in the version 2.2.1 and earlier.
//
Procedure SetOutputModeInReportPanels(Settings, ReportOrSubsystem, OutputReportsInsteadVariants) Export
	If TypeOf(OutputReportsInsteadVariants) <> Type("Boolean") Then
		OutputReportsInsteadVariants = (OutputReportsInsteadVariants = Upper("ByReports"));
	EndIf;
	If TypeOf(ReportOrSubsystem) = Type("ValueTreeRow")
		Or Metadata.Reports.Contains(ReportOrSubsystem) Then
		SetReportOutputModeInReportsPanels(Settings, ReportOrSubsystem, OutputReportsInsteadVariants);
	Else
		Subsystems = New Array;
		Subsystems.Add(ReportOrSubsystem);
		Quantity = 1;
		ProcessedObjects = New Array;
		While Quantity > 0 Do
			Quantity = Quantity - 1;
			Subsystem = Subsystems[0];
			Subsystems.Delete(0);
			For Each NestedSubsystem IN Subsystem.Subsystems Do
				Quantity = Quantity + 1;
				Subsystems.Add(NestedSubsystem);
			EndDo;
			For Each MetadataObject IN ReportOrSubsystem.Content Do
				If ProcessedObjects.Find(MetadataObject) = Undefined Then
					ProcessedObjects.Add(MetadataObject);
					If Metadata.Reports.Contains(MetadataObject) Then
						SetReportOutputModeInReportsPanels(Settings, MetadataObject, OutputReportsInsteadVariants);
					EndIf;
				EndIf;
			EndDo;
		EndDo;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// To call from reports forms.

// Updates the UserReportsSettings catalog content after saving a new setting.
//   It is called from the report form handler with the same name once the form code is executed.
//
// Parameters:
//   Form - ManagedForm - Report form.
//   Settings - MetadataObject - It is passed  "as it is"  from the OnSaveUserSettingsAtServer procedure.
//
Procedure OnSaveUserSettingsAtServer(Form, Settings) Export
	
	FormAttributes = New Structure("ObjectKey, VariantRef");
	FillPropertyValues(FormAttributes, Form);
	If Not ValueIsFilled(FormAttributes.ObjectKey)
		Or Not ValueIsFilled(FormAttributes.VariantRef) Then
		ReportObject = Form.FormAttributeToValue("Report");
		ReportMetadata = ReportObject.Metadata();
		If Not ValueIsFilled(FormAttributes.ObjectKey) Then
			FormAttributes.ObjectKey = ReportMetadata.FullName();
		EndIf;
		If Not ValueIsFilled(FormAttributes.VariantRef) Then
			ReportInformation = GenerateInformationAboutReportByDescriptionFull(FormAttributes.ObjectKey);
			If Not ValueIsFilled(ReportInformation.ErrorText) Then
				ReportRef = ReportInformation.Report;
			Else
				ReportRef = FormAttributes.ObjectKey;
			EndIf;
			FormAttributes.VariantRef = GetRef(ReportRef, Form.CurrentVariantKey);
		EndIf;
	EndIf;
	
	SettingsKey = FormAttributes.ObjectKey + "/" + Form.CurrentVariantKey;
	SettingsList = ReportsUserSettingsStorage.GetList(SettingsKey);
	SettingsCount = SettingsList.Count();
	UserRef = Users.AuthorizedUser();
	
	QueryText =
	"SELECT ALLOWED
	|	*
	|FROM
	|	Catalog.UserReportsSettings AS UserReportsSettings
	|WHERE
	|	UserReportsSettings.Variant = &VariantRef
	|	AND UserReportsSettings.User = &UserRef
	|
	|ORDER BY
	|	UserReportsSettings.DeletionMark";
	
	Query = New Query;
	Query.SetParameter("VariantRef", FormAttributes.VariantRef);
	Query.SetParameter("UserRef", UserRef);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		ItemOfList = SettingsList.FindByValue(Selection.UserSettingKey);
		
		DeletionMark = (ItemOfList = Undefined);
		If DeletionMark <> Selection.DeletionMark Then
			SettingsObject = Selection.Ref.GetObject();
			SettingsObject.SetDeletionMark(DeletionMark);
		EndIf;
		If DeletionMark Then
			If SettingsCount = 0 Then
				Break;
			Else
				Continue;
			EndIf;
		EndIf;
		
		If Selection.Description <> ItemOfList.Presentation Then
			SettingsObject = Selection.Ref.GetObject();
			SettingsObject.Description = ItemOfList.Presentation;
			SettingsObject.Write();
		EndIf;
		
		SettingsList.Delete(ItemOfList);
		SettingsCount = SettingsCount - 1;
	EndDo;
	
	For Each ItemOfList IN SettingsList Do
		SettingsObject = Catalogs.UserReportsSettings.CreateItem();
		SettingsObject.Description                  = ItemOfList.Presentation;
		SettingsObject.UserSettingKey = ItemOfList.Value;
		SettingsObject.Variant                       = FormAttributes.VariantRef;
		SettingsObject.User                  = UserRef;
		SettingsObject.Write();
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// To call configuration from "OnAddUpdateHandlers" event.

// Full update of reports variants search index.
//   You should call from OnAddUpdateHandlers procedure of configuration.
//   Warning! This procedure should be called only once - from the module of the end applied solution.
//     It is not designed for call from libraries.
//
// Parameters:
//   Handlers - Collection - Passed “as it is” from the called procedure.
//   Version - String - Configuration version during transition
//       to which it is required to update the search index completely.
//     It is recommended to
//       specify the last functional version during the
//       update for which the metadata objects or
//       their properties presentations are changed, which can be displayed in reports.
//     Risen if necessary.
//
// ForExample:
// ReportsVariants.AddFullUpdateHandlers(Handlers, "11.1.7.8");
//
// Usage location:
//   <ConfigurationModule>.OnAddUpdateHandlers().
//
// See also:
//   ConfigurationSubsystemsOverridable.OnAddSubsystems().
//
Procedure AddFullUpdateHandlers(Handlers, Version) Export
	
	If UndividedDataIndexationAllowed() Then
		Handler = Handlers.Add();
		Handler.PerformModes = ?(CommonUseReUse.DataSeparationEnabled(), "Exclusive", "Delay");
		Handler.SharedData     = True;
		Handler.Version    = Version;
		Handler.Procedure = "ReportsVariants.DeferredGeneralDataFullUpdate";
		Handler.Comment = NStr("en='Full update of an reports search index that are provided in the application.
		|Reports search is temporary unavailable.';ru='Полное обновление индекса поиска отчетов, предусмотренных в программе.
		|Поиск отчетов временно недоступен.'");
	EndIf;
	
	Handler = Handlers.Add();
	Handler.PerformModes = "Delay";
	Handler.SharedData     = False;
	Handler.Version    = Version;
	Handler.Procedure = "ReportsVariants.DeferredSeparatedDataFullUpdate";
	Handler.Comment = NStr("en='Full update of reports search index saved by users.
		|Reports search is temporary unavailable.';ru='Полное обновление индекса поиска отчетов, сохраненных пользователями.
		|Поиск отчетов временно недоступен.'");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// To call applied configuration from update handlers.

// Transfers user variants from the variants standard storage to subsystem storage.
//   Used during the partial implementation - when ReportsVariantsStorage is set not for
//   the whole configuration but in the properties of the specific reports connected to subsystem.
//   It is recommended to use in update handlers for the specified version.
//
// Parameters:
//   NamesReports - String - Optional. Reports names separated by commas.
//
// Example:
// // Transfer all reports user variants during the update.
// ReportsVariants.TransferReportsVariantsFromStandardStorage();
// // Or transfer user reports variants that are transferred to the "Reports variants" subsystem storage.
// ReportsVariants.TransferReportsVariantsFromStandardStorage("EventLogMonitorAnalysis, JobsExpiredByDate");
//
Procedure TransferUserOnesFromStandardStorage(NamesReports = "") Export
	ProcedureRepresentation = NStr("en='Direct report variant conversion';ru='Прямая конвертация вариантов отчетов'");
	ProcedureLaunch(ProcedureRepresentation);
	
	// Result that will be saved in the storage.
	VariantTable = CommonUse.CommonSettingsStorageImport("TransferReportVariants", "VariantTable", , , "");
	If TypeOf(VariantTable) <> Type("ValueTable") Or VariantTable.Count() = 0 Then
		VariantTable = New ValueTable;
		VariantTable.Columns.Add("Report",     TypeDescriptionString());
		VariantTable.Columns.Add("Variant",   TypeDescriptionString());
		VariantTable.Columns.Add("Author",     TypeDescriptionString());
		VariantTable.Columns.Add("Setting", New TypeDescription("ValueStorage"));
		VariantTable.Columns.Add("ReportPresentation",   TypeDescriptionString());
		VariantTable.Columns.Add("VariantPresentation", TypeDescriptionString());
		VariantTable.Columns.Add("AuthorID",   New TypeDescription("UUID"));
	EndIf;
	
	DeleteAll = (NamesReports = "" Or NamesReports = "*");
	DeletedObjectKeysArray = New Array;
	
	StorageSelection = ReportsVariantsStorage.Select(NewFilterByObjectKey(NamesReports));
	ReadErrorsInRow = 0;
	While True Do
		Try
			ItemSampleIsObtained = StorageSelection.Next();
			ReadErrorsInRow = 0;
		Except
			ItemSampleIsObtained = Undefined;
			ReadErrorsInRow = ReadErrorsInRow + 1;
			ErrorByVariant(
				Undefined,
				NStr("en='An error occurred while selecting reports variants from the standard storage';ru='В процессе выборки вариантов отчетов из стандартного хранилища возникла ошибка:'")
				+ Chars.LF
				+ DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		If ItemSampleIsObtained = False Then
			If NamesReports = "" Or NamesReports = "*" Then
				Break;
			Else
				StorageSelection = ReportsVariantsStorage.Select(NewFilterByObjectKey(NamesReports));
				Continue;
			EndIf;
		ElsIf ItemSampleIsObtained = Undefined Then
			If ReadErrorsInRow > 100 Then
				Break;
			Else
				Continue;
			EndIf;
		EndIf;
		
		// Skip unconnected internal reports.
		ReportMetadata = Metadata.FindByFullName(StorageSelection.ObjectKey);
		If ReportMetadata <> Undefined Then
			ConfigurationRepositoryMetadata = ReportMetadata.VariantsStorage;
			If ConfigurationRepositoryMetadata = Undefined Or ConfigurationRepositoryMetadata.Name <> "ReportsVariantsStorage" Then
				DeleteAll = False;
				Continue;
			EndIf;
		EndIf;
		
		// Reports external variants are all transferred as it is
		// impossible to determine for them whether they are  connected to the storage or not.
		DeletedObjectKeysArray.Add(StorageSelection.ObjectKey);
		
		IBUser = InfobaseUsers.FindByName(StorageSelection.User);
		If IBUser = Undefined Then
			User = Catalogs.Users.FindByDescription(StorageSelection.User, True);
			If Not ValueIsFilled(User) Then
				Continue;
			EndIf;
			UserID = User.InfobaseUserID;
		Else
			UserID = IBUser.UUID;
		EndIf;
		
		TableRow = VariantTable.Add();
		TableRow.Report     = StorageSelection.ObjectKey;
		TableRow.Variant   = StorageSelection.SettingsKey;
		TableRow.Author     = StorageSelection.User;
		TableRow.Setting = New ValueStorage(StorageSelection.Settings, New Deflation(9));
		TableRow.VariantPresentation = StorageSelection.Presentation;
		TableRow.AuthorID   = UserID;
		If ReportMetadata = Undefined Then
			TableRow.ReportPresentation = StorageSelection.ObjectKey;
		Else
			TableRow.ReportPresentation = ReportMetadata.Presentation();
		EndIf;
	EndDo;
	
	// Clear standard storage.
	If DeleteAll Then
		ReportsVariantsStorage.Delete(Undefined, Undefined, Undefined);
	Else
		For Each ObjectKey IN DeletedObjectKeysArray Do
			ReportsVariantsStorage.Delete(ObjectKey, Undefined, Undefined);
		EndDo;
	EndIf;
	
	// Execution result
	ProcedureCompletion(ProcedureRepresentation);
	
	// Import variants to subsystem storage.
	ImportCustom(VariantTable);
EndProcedure

// Imports reports variants subsystems to the
//   storage that were saved from the variants system storage to the general settings storage.
//   It is used to load report variants on full or partial implementation.
//   If there is a full embedding, it can be called from "ReportVariantsTransfer" processor.
//   It is recommended to use in update handlers for the specified version.
//
// Parameters:
//   VariantTable - ValueTable - Optional. Used in the service scripts.
//       * Report   - String - Report full name as "Report.<ReportName>".
//       * Variant - String - Report variant name.
//       * Author   - String - Username.
//       * Setting - ValueStorage - DataLayoutUserSettings
//       * ReportPresentaton   - String - Report presentaton .
//       * VariantPresentation - String - Variant presentation.
//       * AuthorID - UUID - User ID.
//
Procedure ImportCustom(VariantTable = Undefined) Export
	
	If VariantTable = Undefined Then
		VariantTable = CommonUse.CommonSettingsStorageImport("TransferReportVariants", "VariantTable", , , "");
	EndIf;
	
	If TypeOf(VariantTable) <> Type("ValueTable") Or VariantTable.Count() = 0 Then
		Return;
	EndIf;
	
	ProcedureRepresentation = NStr("en='Complete the report variants conversion';ru='Завершить конвертацию вариантов отчетов'");
	ProcedureLaunch(ProcedureRepresentation);
	
	// Columns names replacement under the catalog structure.
	VariantTable.Columns.Report.Name = "ReportFullName";
	VariantTable.Columns.Variant.Name = "VariantKey";
	VariantTable.Columns.VariantPresentation.Name = "Description";
	
	// Convert reports names to MOI catalog refs.
	VariantTable.Columns.Add("Report", Metadata.Catalogs.ReportsVariants.Attributes.Report.Type);
	VariantTable.Columns.Add("Defined", New TypeDescription("Boolean"));
	VariantTable.Columns.Add("ReportType", Metadata.Catalogs.ReportsVariants.Attributes.ReportType.Type);
	For Each TableRow IN VariantTable Do
		ReportInformation = GenerateInformationAboutReportByDescriptionFull(TableRow.ReportFullName);
		
		// Check result
		If TypeOf(ReportInformation.ErrorText) = Type("String") Then
			ErrorByVariant(Undefined, ReportInformation.ErrorText);
			Continue;
		EndIf;
		
		TableRow.Defined = True;
		FillPropertyValues(TableRow, ReportInformation, "Report, ReportType");
	EndDo;
	
	VariantTable.Sort("ReportFullName Asc, VariantKey Asc");
	
	// Existing reports variants.
	QueryText =
	"SELECT
	|	VariantTable.Report,
	|	VariantTable.ReportFullName,
	|	VariantTable.ReportType,
	|	VariantTable.VariantKey,
	|	VariantTable.Author
	|INTO ttOptions
	|FROM
	|	&VariantTable AS VariantTable
	|WHERE
	|	VariantTable.Defined = TRUE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ttOptions.Report,
	|	ttOptions.ReportFullName,
	|	ttOptions.ReportType,
	|	ttOptions.VariantKey,
	|	ReportsVariants.Ref,
	|	UsersByName.Ref AS UserByName
	|FROM
	|	ttOptions AS ttOptions
	|		LEFT JOIN Catalog.Users AS UsersByName
	|		ON ttOptions.Author = UsersByName.Description
	|			AND (UsersByName.DeletionMark = FALSE)
	|		LEFT JOIN Catalog.ReportsVariants AS ReportsVariants
	|		ON ttOptions.Report = ReportsVariants.Report
	|			AND ttOptions.VariantKey = ReportsVariants.VariantKey
	|			AND ttOptions.ReportType = ReportsVariants.ReportType";
	
	Query = New Query;
	Query.SetParameter("VariantTable", VariantTable);
	Query.Text = QueryText;
	
	DBVariants = Query.Execute().Unload();
	
	// Authors of variants
	QueryText =
	"SELECT
	|	Users.Ref AS User,
	|	Users.InfobaseUserID AS ID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.InfobaseUserID IN(&IDs)
	|	AND Users.DeletionMark = FALSE";
	
	Query = New Query;
	Query.SetParameter("IDs", VariantTable.UnloadColumn("AuthorID"));
	Query.Text = QueryText;
	
	UsersByIdentifier = Query.Execute().Unload();
	
	ReportsSubsystems = PlacingReportsInSubsystems();
	
	// Import variants to subsystem storage.
	DefinedVariants = VariantTable.FindRows(New Structure("Defined", True));
	For Each TableRow IN DefinedVariants Do
		Found = DBVariants.FindRows(New Structure("Report, VariantKey", TableRow.Report, TableRow.VariantKey));
		DBVariant = Found[0];
		
		// If variant is already imported to the "Reports variants" catalog. - do not load it.
		If ValueIsFilled(DBVariant.Ref) Then
			Continue;
		EndIf;
		
		// CatalogObject
		VariantObject = Catalogs.ReportsVariants.CreateItem();
		
		// Already prepared parameters.
		FillPropertyValues(VariantObject, TableRow, "Description, Report, ReportType, VariantKey");
		
		// Settings
		Settings = TableRow.Setting;
		If TypeOf(Settings) = Type("ValueStorage") Then
			Settings = Settings.Get();
		EndIf;
		VariantObject.Settings = New ValueStorage(Settings);
		
		// Only user RV are stored in the standard storage.
		VariantObject.User = True;
		VariantObject.ForAuthorOnly = True;
		
		// Author of the variant
		UserByID = UsersByIdentifier.Find(TableRow.AuthorID, "ID");
		If UserByID <> Undefined AND ValueIsFilled(UserByID.User) Then
			VariantObject.Author = UserByID.User;
		ElsIf DBVariant <> Undefined AND ValueIsFilled(DBVariant.UserByName) Then
			VariantObject.Author = DBVariant.UserByName;
		Else
			ErrorByVariant(
				VariantObject.Ref,
				NStr("en='Variant ""%1"" of report ""%2"": author is not found ""%3""';ru='Вариант ""%1"" отчета ""%2"": не найден автор ""%3""'"),
				VariantObject.Description,
				TableRow.ReportPresentation,
				TableRow.Author);
		EndIf;
		
		// As user reports variants
		// are transferred, placing settings can be taken only from report metadata.
		Found = ReportsSubsystems.FindRows(New Structure("ReportFullName", TableRow.ReportFullName));
		For Each RowSubsystem IN Found Do
			RowSection = VariantObject.Placement.Add();
			RowSection.Use = True;
			RowSection.Subsystem = CommonUse.MetadataObjectID(RowSubsystem.SubsystemMetadata);
		EndDo;
		
		VariantObject.Write();
	EndDo;
	
	// Clearing
	CommonUse.CommonSettingsStorageDelete("TransferReportVariants", "VariantTable", "");
	
	ProcedureCompletion(ProcedureRepresentation);
EndProcedure

#EndRegion

#Region ServiceApplicationInterface

////////////////////////////////////////////////////////////////////////////////
// Add handlers of the service events (subsriptions).

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Contains the settings of reports variants placement in reports panel.
	//
	// Parameters:
	//   Settings - Collection - Used for the description of reports
	//       settings and options, see description to ReportsVariants.ConfigurationReportVariantsSetupTree().
	//
	// Definition:
	//  See ReportsVariantsOverride.SetupReportsVariants().
	//
	ServerEvents.Add(
		"StandardSubsystems.ReportsVariants\OnConfiguringOptionsReports");
	
	// Register changes in the report variants names.
	//   Used in the update handlers to control
	//   reference integrity and to save settings created by administrator for the predefined documents.
	//
	// Parameters:
	//   Changes - ValueTable - Changes in reports variants names.
	//       * Report - MetadataObject - Report metadata in the schema of which variant name is changed.
	//       * VariantOldName - String - Variant old name before change.
	//       * VariantActualName - String - Variant current (last relevant) name.
	//
	// Definition:
	//  See ReportsVariantsPredefined.RegisterReportsVariantsKeysChanges().
	//
	ServerEvents.Add(
		"StandardSubsystems.ReportsVariants\OnRegisterReportVariantNamesChanges");
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	// SERVERSIDE HANDLERS.
	ServerModule = "ReportsVariants";
	
	Event = "StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers";
	ServerHandlers[Event].Add(ServerModule);
	
	Event = "StandardSubsystems.BasicFunctionality\OnAddExceptionsSearchLinks";
	ServerHandlers[Event].Add(ServerModule);
	
	Event = "StandardSubsystems.BasicFunctionality\OnAddMetadataObjectsRenaming";
	ServerHandlers[Event].Add(ServerModule);
	
	Event = "StandardSubsystems.BasicFunctionality\OnGettingObligatoryExchangePlanObjects";
	ServerHandlers[Event].Add(ServerModule);
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		Event = "ServiceTechnology.DataExportImport\WhenFillingCommonDataTypesSupportingMatchingRefsOnImport";
		ServerHandlers[Event].Add(ServerModule);
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of service events.

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//   Handlers - ValueTable - Update handlers.
//      See description of method InfobaseUpdate.UpdateHandlersNewTable().
//
Procedure OnAddUpdateHandlers(Handlers) Export
	
	////////////////////////////////////////////////////////////////////////////////
	// Update plan:
	
	////////////////////////////////////////////////////////////////////////////////
	// 1. Update common data.
	Handler = Handlers.Add();
	Handler.ExecuteUnderMandatory = False;
	Handler.SharedData                  = True;
	Handler.HandlersManagement      = True;
	Handler.PerformModes              = "Promptly";
	Handler.Version    = "*";
	Handler.Procedure = "ReportsVariants.UpdateCommonData";
	Handler.Priority = 90;
	
	////////////////////////////////////////////////////////////////////////////////
	// 2. Update separated data.
	// 2.1. Transfer separated data to version 2.1.1.0.
	Handler = Handlers.Add();
	Handler.ExecuteUnderMandatory = True;
	Handler.SharedData                  = False;
	Handler.HandlersManagement      = False;
	Handler.PerformModes              = "Exclusive";
	Handler.Version    = "2.1.1.0";
	Handler.Procedure = "ReportsVariants.GoToEdition21";
	Handler.Priority = 80;
	
	// 2.2. Transfer separated data to version 2.1.3.6.
	Handler = Handlers.Add();
	Handler.ExecuteUnderMandatory = True;
	Handler.SharedData                  = False;
	Handler.HandlersManagement      = False;
	Handler.PerformModes              = "Exclusive";
	Handler.Version    = "2.1.3.6";
	Handler.Procedure = "ReportsVariants.FillRefsPredefined";
	Handler.Priority = 80;
	
	// 2.3. Update separated data in the local mode.
	Handler = Handlers.Add();
	Handler.PerformModes = "Promptly";
	Handler.Version    = "*";
	Handler.Procedure = "ReportsVariants.UpdateDividedData";
	Handler.Priority = 70;
	
	////////////////////////////////////////////////////////////////////////////////
	// 3. Update is postponed.
	// 3.1. Fill in information to search for reports variants.
	
	If UndividedDataIndexationAllowed() Then
		Handler = Handlers.Add();
		Handler.PerformModes = ?(CommonUseReUse.DataSeparationEnabled(), "Promptly", "Delay");
		Handler.SharedData     = True;
		Handler.Version      = "*";
		Handler.Procedure   = "ReportsVariants.DeferredGeneralDataIncrementalUpdate";
		Handler.Comment = NStr("en='Incremental update of reports search update present in the application.
		|Reports search is temporary unavailable.';ru='Инкрементальное обновление индекса поиска отчетов, предусмотренных в программе.
		|Поиск отчетов временно недоступен.'");
	EndIf;
	
	// 3.2. Fill in information to search for reports variants.
	Handler = Handlers.Add();
	Handler.PerformModes = "Delay";
	Handler.SharedData     = False;
	Handler.Version    = "2.2.3.31";
	Handler.Procedure = "ReportsVariants.ReduceQuickSettingsQuantity";
	Handler.Comment = NStr("en='Decreases the quick
		|settings quantity in the user reports down to 2.';ru='Уменьшает
		|количество быстрых настроек в пользовательских отчетах до 2 шт.'");
	
EndProcedure

// Appears while receiving refs search exceptions.
Procedure OnAddExceptionsSearchLinks(RefsSearchExceptions) Export
	
	RefsSearchExceptions.Add(Metadata.Catalogs.ReportsVariants.TabularSections.Placement.Attributes.Subsystem);
	
EndProcedure

// Fills those metadata objects renaming that can not be automatically found by type, but the references to which are to be stored in the database (for example, subsystems, roles).
//
// See also:
//   CommonUse.AddRenaming().
//
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	CommonUse.AddRenaming(
		Total, "2.1.0.2", "Role.ReadReportVariants", "Role.ReportsVariantsUsage", Library);
	
EndProcedure

// Used to receive metadata objects mandatory for an exchange plan.
// If the subsystem has metadata objects that have to be included
// in the exchange plan, then these metadata objects should be added to the <Object> parameter.
//
// See also:
//   StandardSubsystemsServer.CheckExchangePlanContent().
//
Procedure OnGettingObligatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.Constants.ReportVariantParameters);
		Objects.Add(Metadata.Catalogs.ReportsVariants);
		Objects.Add(Metadata.Catalogs.PredefinedReportsVariants);
		Objects.Add(Metadata.Catalogs.UserReportsSettings);
		Objects.Add(Metadata.InformationRegisters.ReportsVariantsSettings);
		
	EndIf;
	
EndProcedure

// Fills the array of types of undivided data for
// which the refs matching during data import to another infobase is supported.
//
// Parameters:
//   Types - Array from MetadataObject.
//
Procedure WhenFillingCommonDataTypesSupportingMatchingRefsOnImport(Types) Export
	
	Types.Add(Metadata.Catalogs.PredefinedReportsVariants);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Conditional call handlers.

// Receives report object by report variant reference.
//
// Parameters:
//   ReferenceOfVariantOrReport -
//     - CatalogRef.ReportsVariants - Report variant reference connected to the subsystem storage.
//     - CatalogRef.MetadataObjectIDs - Configuration report reference.
//     - Arbitrary - Additional or external report reference.
//
// Returns:
//   Structure - Report parameters including Report object.
//       * Object     - ReportObject.<Report name>, ExternalReport - Report object.
//       * Name        - String           - Report object name.
//       * Metadata - MetadataObject - Report metadata object.
//       * Ref     - Arbitrary     - Report refs.
//       *Errors     - String           - Error text.
//
// Usage location:
//   ReportsMailing.InitializeReport().
//
Function ConnectReportObject(ReferenceOfVariantOrReport) Export
	Result = New Structure;
	Result.Insert("Object",     Undefined);
	Result.Insert("Name",        "");
	Result.Insert("DescriptionFull",  "");
	Result.Insert("Metadata", Undefined);
	Result.Insert("Ref",     Undefined);
	Result.Insert("Connected",  False);
	Result.Insert("Errors",     "");
	
	If TypeOf(ReferenceOfVariantOrReport) = Type("CatalogRef.ReportsVariants") Then
		Result.Ref = CommonUse.ObjectAttributeValue(ReferenceOfVariantOrReport, "Report");
	Else
		Result.Ref = ReferenceOfVariantOrReport;
	EndIf;
	
	If Result.Ref = Undefined Then
		Result.Errors = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Report variant ""%1"" is not found in the application';ru='Вариант отчета ""%1"" не найден в программе'"),
			String(ReferenceOfVariantOrReport));
		Return Result;
	ElsIf TypeOf(Result.Ref) = Type("String") Then
		Result.Errors = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='For the variant ""%1"" report ""%2"" is written as external and can not be connected from the application';ru='Для варианта ""%1"" отчет ""%2"" записан как внешний и не может быть подключен из программы'"),
			String(ReferenceOfVariantOrReport),
			Result.Ref);
		Return Result;
	EndIf;
	
	If TypeOf(Result.Ref) = Type("CatalogRef.MetadataObjectIDs") Then
		Result.Name = CommonUse.ObjectAttributeValue(Result.Ref, "Name");
		Result.Metadata = Metadata.Reports.Find(Result.Name);
		If Result.Metadata = Undefined Then
			Result.Errors = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='For variant ""%1"" report ""%2"" is not found in the application';ru='Для варианта ""%1"" отчет ""%2"" не найден в программе'"),
				String(ReferenceOfVariantOrReport),
				Result.Name);
			Return Result;
		EndIf;
		
		Result.Object = Reports[Result.Name].Create();
		Result.Connected = True;
	Else
		If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
			ModuleAdditionalReportsAndDataProcessors.OnConnectingAdd1Report(Result.Ref, Result, Result.Connected);
		EndIf;
	EndIf;
	
	If Result.Connected Then
		Result.DescriptionFull = Result.Metadata.FullName();
	EndIf;
	
	Return Result;
EndFunction

// Updates additional report variants during its writing.
//
// Usage location:
//   Catalog.AdditionalReportsAndDataProcessors.OnWriteGlobalReport().
//
Procedure OnWriteAdditionalReport(CurrentObject, Cancel, ExternalObject) Export
	
	If Not ReportsVariantsReUse.AddRight() Then
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='You are not authorized to write variants of additional report ""%1"".';ru='Недостаточно прав доступа для записи вариантов дополнительного отчета ""%1"".'"),
			CurrentObject.Description);
		ErrorByVariant(CurrentObject.Ref, ErrorText);
		CommonUseClientServer.MessageToUser(ErrorText);
		Return;
	EndIf;
	
	DeletionMark = CurrentObject.DeletionMark;
	If Not CurrentObject.UsesVariantsStorage Or Not CurrentObject.AdditionalProperties.PublicationIsUsed Then
		DeletionMark = True;
	EndIf;
	
	PredefinedVariants = New ValueList;
	If CurrentObject.UsesVariantsStorage Then
		ReportMetadata = ExternalObject.Metadata();
		DCSchemaMetadata = ReportMetadata.MainDataCompositionSchema;
		If DCSchemaMetadata <> Undefined Then
			DCSchema = ExternalObject.GetTemplate(DCSchemaMetadata.Name);
			For Each DCSettingsVariant IN DCSchema.SettingVariants Do
				PredefinedVariants.Add(DCSettingsVariant.Name, DCSettingsVariant.Presentation);
			EndDo;
		Else
			PredefinedVariants.Add("", ReportMetadata.Presentation());
		EndIf;
	EndIf;
	
	// If you clear deletion mark of the additional report, deletion mark clears only
	// for the predefined reports variants (it does not clear for the user ones).
	QueryText =
	"SELECT ALLOWED
	|	Table.Ref,
	|	Table.VariantKey,
	|	Table.User,
	|	Table.DeletionMark,
	|	Table.Description
	|FROM
	|	Catalog.ReportsVariants AS Table
	|WHERE
	|	Table.Report = &Report
	|	AND Table.User = FALSE";
	
	Query = New Query;
	Query.SetParameter("Report", CurrentObject.Ref);
	If DeletionMark = True Then
		// While setting mark for deletion of add. report mark for deletion is set for all reports variants - and
		// user and predefined.
		QueryText = StrReplace(QueryText, "AND Table.User = FALSE", "");
	EndIf;
	Query.Text = QueryText;
	
	// Deletion mark setting.
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		OptionDeletionMark = DeletionMark;
		ItemOfList = PredefinedVariants.FindByValue(Selection.VariantKey);
		If Not OptionDeletionMark AND Not Selection.User AND ItemOfList = Undefined Then
			// Predefined variant that is not found in the list of the predefined ones for the current report.
			OptionDeletionMark = True;
		EndIf;
		
		If Selection.DeletionMark <> OptionDeletionMark Then
			VariantObject = Selection.Ref.GetObject();
			VariantObject.AdditionalProperties.Insert("PredefinedOnesFilling", True);
			If OptionDeletionMark Then
				VariantObject.AdditionalProperties.Insert("IndexSchema", False);
			Else
				VariantObject.AdditionalProperties.Insert("ReportObject", ExternalObject);
			EndIf;
			VariantObject.SetDeletionMark(OptionDeletionMark);
		EndIf;
		
		If ItemOfList <> Undefined Then
			PredefinedVariants.Delete(ItemOfList);
			If Selection.Description <> ItemOfList.Presentation Then
				VariantObject = Selection.Ref.GetObject();
				VariantObject.Description = ItemOfList.Presentation;
				VariantObject.AdditionalProperties.Insert("ReportObject", ExternalObject);
				VariantObject.Write();
			EndIf;
		EndIf;
	EndDo;
	
	If Not DeletionMark Then
		// Register new
		For Each ItemOfList IN PredefinedVariants Do
			VariantObject = Catalogs.ReportsVariants.CreateItem();
			VariantObject.Report                = CurrentObject.Ref;
			VariantObject.ReportType            = Enums.ReportsTypes.Additional;
			VariantObject.VariantKey         = ItemOfList.Value;
			VariantObject.Description         = ItemOfList.Presentation;
			VariantObject.User     = False;
			VariantObject.VisibleByDefault = True;
			VariantObject.AdditionalProperties.Insert("ReportObject", ExternalObject);
			VariantObject.Write();
		EndDo;
	EndIf;
	
EndProcedure

// Receives passed report variants and their presentations.
//
// Usage location:
//   UsersService.OnGetUserReportsVariants().
//
Procedure UserReportsVariants(ReportMetadata, InfobaseUser, ReportVariantsTable, StandardProcessing) Export
	
	ReportKey = "Report" + "." + ReportMetadata.Name;
	AllReportVariants = SettingsStorages.ReportsVariantsStorage.GetList(ReportKey, InfobaseUser);
	ReportVariants = New ValueList;
	
	For Each ReportVariant IN AllReportVariants Do
		
		CatalogItem = Catalogs.ReportsVariants.FindByDescription(ReportVariant.Presentation);
		
		If CatalogItem <> Undefined
			AND CatalogItem.ForAuthorOnly Then
			
			ReportVariantsRow = ReportVariantsTable.Add();
			ReportVariantsRow.ObjectKey = "Report." + ReportMetadata.Name;
			ReportVariantsRow.VariantKey = ReportVariant.Value;
			ReportVariantsRow.Presentation = ReportVariant.Presentation;
			ReportVariantsRow.StandardProcessing = False;
			
			StandardProcessing = False;
			
		ElsIf CatalogItem <> Undefined Then
			StandardProcessing = False;
		EndIf;
		
	EndDo;
	
EndProcedure

// Deletes the passed report variant from reports variants storage.
//
// Usage location:
//   UsersService.OnDeleteUserReportsVariants().
//
Procedure DeleteUserReportVariant(InfoAboutReportOption, InfobaseUser, StandardProcessing) Export
	
	If InfoAboutReportOption.StandardProcessing Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	SettingsStorages.ReportsVariantsStorage.Delete(InfoAboutReportOption.ObjectKey,
		InfoAboutReportOption.VariantKey, InfobaseUser);
	
EndProcedure

// Adds alert for the subsystem opened forms if functional option value is changed.
//
// Parameters:
//   Result - Structure - Server work result that is returned to client.
//      See StandardSubsystemsClient.ShowExecutionResult().
//   ConstantManager - ConstantManager.<Constant name> - Constant manager the value of which was changed.
//
// Definition:
//   This procedure should be used while changing
//   constants values that are associated with functional options for the subsequent open forms update.
//
// Usage location:
//   DataProcessor.AdministrationPanelSSL.Form.*.
//
Procedure AddNotificationOnValueChangeConstants(Result, ConstantManager) Export
	// Reports variants are connected with constants via functional options.
	// ReUse is not used as its values are reset as a rule during change of the functional option.
	VariablesInitialized = False;
	ConstantMetadata = ConstantManager.CreateValueManager().Metadata();
	
	// Search for functional options related to this constant.
	For Each FunctionalOptionMetadata IN Metadata.FunctionalOptions Do
		If FunctionalOptionMetadata.Location = ConstantMetadata Then
			
			// Search for reports variants connection with this functional option.
			If Not VariablesInitialized Then
				VariablesInitialized = True;
				OptionsTable = Constants.ReportVariantParameters.Get().Get().TableFunctionalOptions;
				EventName = ReportsVariantsClientServer.EventNameOptionChanging();
			EndIf;
			
			If OptionsTable.Find(FunctionalOptionMetadata.Name, "FunctionalOptionName") <> Undefined Then
				StandardSubsystemsClientServer.ExecutionResultAddNotificationOfOpenForms(Result, EventName);
				Return;
			EndIf;
			
			// Search for reports connection with this functional option.
			For Each FunctionalOptionContentItem IN FunctionalOptionMetadata.Content Do
				If TypeOf(FunctionalOptionContentItem.Object) = Type("MetadataObject")
					AND Metadata.Reports.Contains(FunctionalOptionContentItem.Object) Then
					StandardSubsystemsClientServer.ExecutionResultAddNotificationOfOpenForms(Result, EventName);
					Return;
				EndIf;
			EndDo;
			
		EndIf;
	EndDo;
	
EndProcedure


// Define the list of catalogs available for import using the Import data from file subsystem.
//
// Parameters:
//  ImportedCatalogs - ValueTable - list of catalogs, to which the data can be imported.
//      * FullName          - String - full name of the catalog (as in the metadata).
//      * Presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	// Import to the UserReportsSettings catalog is prohibited.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.UserReportsSettings.FullName(), "DescriptionFull");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;
	
EndProcedure

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.ReportsVariants.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.UserReportsSettings.FullName(), "EditedAttributesInGroupDataProcessing");
	Objects.Insert(Metadata.Catalogs.PredefinedReportsVariants.FullName(), "EditedAttributesInGroupDataProcessing");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures of the service application interface.

// Actualizes subsystem data considering the application work mode.
//   Usage example: setting storages clearing field.
Procedure Refresh(Settings = Undefined) Export
	
	If Settings = Undefined Then
		Settings = New Structure("SharedData, SeparatedData");
		
		RunMode = CommonUseReUse.ApplicationRunningMode();
		If RunMode.SaaS Then
			If CommonUse.UseSessionSeparator() Then
				Settings.SharedData       = False;
				Settings.SeparatedData = True;
			Else
				Settings.SharedData       = True;
				Settings.SeparatedData = False;
			EndIf;
		Else
			If RunMode.Standalone Then
				Settings.SharedData       = False;
				Settings.SeparatedData = True;
			Else
				Settings.SharedData       = True;
				Settings.SeparatedData = True;
			EndIf;
		EndIf;
	EndIf;
	
	If Settings.SharedData = True Then
		UpdateParameters = New Structure("SeparatedHandlers");
		UpdateParameters.SeparatedHandlers = InfobaseUpdate.NewUpdateHandlersTable();
		UpdateCommonData(UpdateParameters);
		DeferredGeneralDataFullUpdate(UpdateParameters);
	EndIf;
	
	If Settings.SeparatedData = True Then
		UpdateDividedData();
		DeferredSeparatedDataFullUpdate();
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Generates a report with the specified settings, used in the background jobs.
Procedure GenerateReport(ReportGenerationParameters, StorageAddress) Export
	
	ReportRef = ReportGenerationParameters.ReportRef;
	If TypeOf(ReportRef) = Type("CatalogRef.MetadataObjectIDs") Then
		ReportObject = Reports[ReportRef.Name].Create();
	Else
		ReportObject = Undefined;
		If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
			ReportObject = ModuleAdditionalReportsAndDataProcessors.GetObjectOfExternalDataProcessor(ReportRef);
		EndIf;
	EndIf;
	
	If ReportObject = Undefined Then
		ErrorByVariant(Undefined, NStr("en='Unable to receive report object ""%1""';ru='Не удалось получить объект отчета ""%1""'"), ReportRef);
		Return;
	EndIf;
	
	ReportObject.SettingsComposer.LoadFixedSettings(ReportGenerationParameters.FixedSettings);
	ReportObject.SettingsComposer.LoadSettings(ReportGenerationParameters.Settings);
	ReportObject.SettingsComposer.LoadUserSettings(ReportGenerationParameters.UserSettings);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	Details = Undefined;
	
	ReportObject.ComposeResult(SpreadsheetDocument, Details);
	
	AdditProperties = ReportObject.SettingsComposer.UserSettings.AdditionalProperties;
	
	GenerationResult = New Structure;
	GenerationResult.Insert("ReportSpreadsheetDocument", SpreadsheetDocument);
	GenerationResult.Insert("ReportDetails", Details);
	GenerationResult.Insert("VariantModified", False);
	GenerationResult.Insert("UserSettingsModified", False);
	
	If CommonUseClientServer.StructureProperty(AdditProperties, "VariantModified") = True Then
		GenerationResult.VariantModified = True;
		GenerationResult.Insert("DCSettings", ReportObject.SettingsComposer.Settings);
	EndIf;
	
	If GenerationResult.VariantModified
		Or CommonUseClientServer.StructureProperty(AdditProperties, "UserSettingsModified") = True Then
		GenerationResult.UserSettingsModified = True;
		GenerationResult.Insert("DCUserSettings", ReportObject.SettingsComposer.UserSettings);
	EndIf;
	
	AdditProperties.Delete("VariantModified");
	AdditProperties.Delete("UserSettingsModified");
	AdditProperties.Delete("VariantKey");
	
	PutToTempStorage(GenerationResult, StorageAddress);
EndProcedure

// Generates a tree of customizing and placing predetermined reports variants.
//   Only for reports connected to the subsystem.
//
// Returns: 
//   OptionsTree - ValueTree - Settings of the predefined reports variants connected to subsystem.
//     Attributes open for change:
//       * Enabled              - Boolean - If False then the report variant is not registered in the subsystem.
//       * VisibleByDefault - Boolean - If False then the report variant is hidden by default in the reports panel.
//       * Description         - String - Report variant description.
//       *Description             - String - Information about report variant.
//       * Placement           - Map - Settings for report variant location in sections.
//           ** Key     - MetadataObject - Subsystem that hosts the report or the report variant.
//           ** Value - String           - Settings placement in subsystem (group).
//               *** ""        - Output report in subsystem without special selection.
//               *** "Important"  - Output report in subsystem From selection bold font.
//               *** "SeeAlso" - Report output in the group "See. also".
//       * FunctionalOptions - Array from String - Names of the functional report variant options.
//       * SettingsForSearch  - Structure - Additional settings for this report variant search.
//           ** FieldsDescription - String - Report variant fields names.
//           ** ParametersAndReportsDescriptions - String - Names of report variant settings.
//           ** TemplatesNames - String - Used instead of FieldsNames.
//               Layouts names of table or
//               text documents from which it is required to extract information about fields names.
//               Names are separated by commas.
//               Unfortunately, there is no information about fields connections and their presentations in layouts (that
//               is present in DLS), that is why for a more accurate search
//               mechanism work it is recommended to fill in FieldsNames, not LayoutsNames.
//       * DefineFormSettings - Boolean - Report has application interface for close integration with
//           the report form. It can also predefine some form settings and subscribe to its events.
//           If True, and the report is connected to
//           common form ReportForm, then a procedure should be defined from a template in the report object module:
//               
//               // Settings of common form for subsystem report "Reports options".
//              
//                Parameters:
//               //   Form - ManagedForm, Undefined - Report form or report settings form.
//                  //    Undefined when call is without context.
//                  VariantKey - String, Undefined - Name
//                      of the pre//defined one or unique identifier of user report variant.
//                      Undefined when call is without context.
//                  Settings - Structure - see return
//                      value Re//portsClientServer.GetReportSettingsByDefault().
//              
//               Procedure DefineFormSettings(Form, VariantKey, Settings)
//               	 Export Procedure code.
//               EndProcedure
//               
//     Service attributes (for reading only):
//       * Report               - <see. Catalogs.ReportsVariants.Attributes.Report> - Full name or reference to report. 
//       * Metadata          - MetadataObject: Report - Metadata report.
//       * VariantKey        - String - Report variant name.
//       * DescriptionReceived    - Boolean - Check box showing that row description is already received.
//           Get description using the VariantDescription() method.
//       * SystemInformation - Structure - Different service info.
//
Function ReportVariantsTreesSettingsConfigurations() Export
	CatalogAttributes = Metadata.Catalogs.ReportsVariants.Attributes;
	
	OptionsTree = New ValueTree;
	OptionsTree.Columns.Add("Report",                CatalogAttributes.Report.Type);
	OptionsTree.Columns.Add("Metadata",           New TypeDescription("MetadataObject"));
	OptionsTree.Columns.Add("VariantKey",         CatalogAttributes.VariantKey.Type);
	OptionsTree.Columns.Add("DescriptionReceived",     New TypeDescription("Boolean"));
	OptionsTree.Columns.Add("Enabled",              New TypeDescription("Boolean"));
	OptionsTree.Columns.Add("VisibleByDefault", New TypeDescription("Boolean"));
	OptionsTree.Columns.Add("Description",         TypeDescriptionString());
	OptionsTree.Columns.Add("Definition",             TypeDescriptionString());
	OptionsTree.Columns.Add("Placement",           New TypeDescription("Map"));
	OptionsTree.Columns.Add("SearchSettings",   New TypeDescription("Structure"));
	OptionsTree.Columns.Add("SystemInfo",  New TypeDescription("Structure"));
	OptionsTree.Columns.Add("IsOption",           New TypeDescription("Boolean"));
	OptionsTree.Columns.Add("FunctionalOptions",  New TypeDescription("Array"));
	OptionsTree.Columns.Add("GroupByReport", New TypeDescription("Boolean"));
	OptionsTree.Columns.Add("DefaultVariant");
	OptionsTree.Columns.Add("DefineFormSettings", New TypeDescription("Boolean"));
	
	OutputReportsInsteadVariants = GlobalSettings().OutputReportsInsteadVariants;
	AllowedIndexing = UndividedDataIndexationAllowed();
	
	ReportsSubsystems = PlacingReportsInSubsystems();
	ConnectedAllReports = ConnectedAllReports();
	For Each ReportMetadata IN Metadata.Reports Do
		If Not ConnectedAllReports Then
			// Check whether the specified report is connected.
			If ReportMetadata.VariantsStorage = Undefined
				Or ReportMetadata.VariantsStorage.Name <> "ReportsVariantsStorage" Then
				Continue;
			EndIf;
		EndIf;
		
		// Settings.
		RowReport = OptionsTree.Rows.Add();
		RowReport.Report                = CommonUse.MetadataObjectID(ReportMetadata);
		RowReport.Metadata           = ReportMetadata;
		RowReport.Enabled              = True;
		RowReport.VisibleByDefault = True;
		RowReport.Definition             = ReportMetadata.Explanation;
		RowReport.Description         = ReportMetadata.Presentation();
		RowReport.DescriptionReceived     = True;
		RowReport.IsOption           = False;
		RowReport.GroupByReport = OutputReportsInsteadVariants;
		RowReport.SystemInfo  = New Structure;
		RowReport.SystemInfo.Insert("BuiltOnDCS", ReportMetadata.MainDataCompositionSchema <> Undefined);
		
		// Subsystems.
		Found = ReportsSubsystems.FindRows(New Structure("ReportMetadata", ReportMetadata));
		For Each RowSubsystem IN Found Do
			RowReport.Placement.Insert(RowSubsystem.SubsystemMetadata, "");
		EndDo;
		
		// Search.
		RowReport.SearchSettings = New Structure("FieldNames, ParametersAndFiltersNames, TemplateNames");
		
		// Predefined variants.
		If RowReport.SystemInfo.BuiltOnDCS Then
			ReportManager = Reports[ReportMetadata.Name];
			DCSchema = Undefined;
			SettingVariants = Undefined;
			Try
				ReportObject = ReportManager.Create();
				RowReport.SystemInfo.Insert("ReportObject", ReportObject);
				DCSchema = ReportObject.DataCompositionSchema;
			Except
				ErrorText = NStr("en='Unable to read report schema ""%1"":';ru='Не удалось прочитать схему отчета ""%1"":'");
				ErrorText = StrReplace(ErrorText, "%1", ReportMetadata.Name);
				ErrorText = ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo());
				WarningByOption(Undefined, ErrorText);
			EndTry;
			// Read report variants settings from schema.
			If DCSchema <> Undefined Then
				Try
					SettingVariants = DCSchema.SettingVariants;
				Except
					ErrorText = NStr("en='Unable to read report variants list ""%1"" from schema:';ru='Не удалось прочитать список вариантов отчета ""%1"" из схемы:'");
					ErrorText = StrReplace(ErrorText, "%1", ReportMetadata.Name);
					ErrorText = ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo());
					WarningByOption(Undefined, ErrorText);
				EndTry;
			EndIf;
			// Reading report variants settings from the manager module (if failed from the scheme).
			If SettingVariants = Undefined Then
				Try
					SettingVariants = ReportManager.SettingVariants();
				Except
					ErrorText = NStr("en='Unable to read report variants list ""%1"" from manager module:';ru='Не удалось прочитать список вариантов отчета ""%1"" из модуля менеджера:'");
					ErrorText = StrReplace(ErrorText, "%1", ReportMetadata.Name);
					ErrorText = ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo());
					ErrorByVariant(Undefined, ErrorText);
				EndTry;
			EndIf;
			// Registration of found variants.
			If SettingVariants <> Undefined Then
				For Each DCSettingsVariant IN SettingVariants Do
					Variant = RowReport.Rows.Add();
					Variant.Report        = RowReport.Report;
					Variant.VariantKey = DCSettingsVariant.Name;
					Variant.Description = DCSettingsVariant.Presentation;
					Variant.IsOption   = True;
					If RowReport.DefaultVariant = Undefined Then
						RowReport.DefaultVariant = Variant;
					EndIf;
					If AllowedIndexing AND TypeOf(DCSettingsVariant) = Type("DataCompositionSettingsVariant") Then
						Try
							Variant.SystemInfo.Insert("DCSettings", DCSettingsVariant.Settings);
						Except
							ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
								NStr("en='Unable to read variant settings ""%1"" of report ""%2"":';ru='Не удалось прочитать настройки варианта ""%1"" отчета ""%2"":'"),
								Variant.VariantKey,
								ReportMetadata.Name)
								+ Chars.LF
								+ DetailErrorDescription(ErrorInfo());
							WarningByOption(Undefined, ErrorText);
						EndTry;
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		
		// Report itself.
		If RowReport.DefaultVariant = Undefined Then
			Variant = RowReport.Rows.Add();
			FillPropertyValues(Variant, RowReport, "Report, Description");
			Variant.VariantKey = "";
			Variant.IsOption   = True;
			RowReport.DefaultVariant = Variant;
		EndIf;
		
	EndDo;
	
	// Extension mechanisms.:
	// Connected handlers of SSL subsystems.
	Handlers = CommonUse.ServiceEventProcessor("StandardSubsystems.ReportsVariants\OnConfiguringOptionsReports");
	For Each Handler IN Handlers Do
		Handler.Module.OnConfiguringOptionsReports(OptionsTree);
	EndDo;
	
	// Predefined part.
	ReportsVariantsOverridable.ConfigureReportsVariants(OptionsTree);
	
	// Define main variants.
	For Each RowReport IN OptionsTree.Rows Do
		If RowReport.GroupByReport = True Then
			If RowReport.DefaultVariant = Undefined
				Or Not RowReport.DefaultVariant.Enabled Then
				For Each Variant IN RowReport.Rows Do
					FillDetailsRowsOption(Variant, RowReport);
					If Variant.Enabled Then
						RowReport.DefaultVariant = Variant;
						Variant.VisibleByDefault = True;
						Break;
					EndIf;
				EndDo;
			EndIf;
		Else
			RowReport.DefaultVariant = Undefined;
		EndIf;
	EndDo;
	
	Return OptionsTree;
EndFunction

// Fills out setting description for the report variant string if it is not filled out.
//
// Parameters:
//   RowOption - TreeRow - Description of report variant settings.
//   RowReport   - TreeRow - Optional. Report settings description.
//
Procedure FillDetailsRowsOption(RowOption, RowReport = Undefined) Export
	If RowOption.DescriptionReceived Then
		Return;
	EndIf;
	
	If RowReport = Undefined Then
		RowReport = RowOption.Parent;
	EndIf;
	
	// Check box of settings change
	RowOption.DescriptionReceived = True;
	
	// Copy report settings.
	FillPropertyValues(RowOption, RowReport, "Enabled, VisibleByDefault, GroupByReport");
	
	If RowOption = RowReport.DefaultVariant Then
		// Default variant.
		RowOption.Definition = RowReport.Definition;
		RowOption.VisibleByDefault = True;
	Else
		// Predefined variant.
		If RowOption.GroupByReport Then
			RowOption.VisibleByDefault = False;
		EndIf;
	EndIf;
	
	RowOption.Placement = CommonUseClientServer.CopyMap(RowReport.Placement);
	RowOption.FunctionalOptions = CommonUseClientServer.CopyArray(RowReport.FunctionalOptions);
	RowOption.SearchSettings = CommonUseClientServer.CopyStructure(RowReport.SearchSettings);
	
EndProcedure

// Sets the report variants output mode in reports panels.
//
// Parameters:
//   OptionsTree - ValueTree - Passed "as it is" from the SetReportsVariants procedure.
//   Report - ValueTreeRow, MetadataObject: Report - Settings description or report metadata.
//   OutputReportsInsteadVariants - Boolean - Output mode in the reports panel:
//       - True - By reports (variants are hidden and report is enabled and visible).
//       - False - By variants (variants are visible and report is disabled).
//
Procedure SetReportOutputModeInReportsPanels(OptionsTree, Report, OutputReportsInsteadVariants)
	If TypeOf(Report) = Type("ValueTreeRow") Then
		RowReport = Report;
	Else
		RowReport = OptionsTree.Rows.Find(Report, "Metadata", False);
		If RowReport = Undefined Then
			WarningByOption(Undefined, NStr("en='Report ""%1"" is not connected to subsystem.';ru='Отчет ""%1"" не подключен к подсистеме.'"), Report.Name);
			Return;
		EndIf;
	EndIf;
	RowReport.GroupByReport = OutputReportsInsteadVariants;
EndProcedure

// Generates a table of variants old keys to relevant ones replacements.
//
// Returns:
//   ValueTable - Variant names changes table. Columns:
//       * ReportMetadata - MetadataObject: Report - Report metadata in the schema of which variant name is changed.
//       * VariantOldName - String - Variant old name before change.
//       * VariantActualName - String - Variant current (last relevant) name.
//       * Report - CatalogRef.MetadataObjectIDs, String - Ref or
//           report name used for storage.
//
// See also:
//   ReportsVariantsOverridable.RegisterReportVariantsKeysChanges().
//   Service event "StandardSubsystems.ReportsVariants\OnChangesReportVariantsNamesRegistration".
//
Function KeysChanges()
	
	VariantKeyAttributeTypeDescription = Metadata.Catalogs.ReportsVariants.Attributes.VariantKey.Type;
	
	Changes = New ValueTable;
	Changes.Columns.Add("Report",                 New TypeDescription("MetadataObject"));
	Changes.Columns.Add("OldOptionName",     VariantKeyAttributeTypeDescription);
	Changes.Columns.Add("ActualOptionName", VariantKeyAttributeTypeDescription);
	
	// Connected handlers of SSL subsystems.
	Handlers = CommonUse.ServiceEventProcessor("StandardSubsystems.ReportsVariants\OnRegisterReportVariantNamesChanges");
	For Each Handler IN Handlers Do
		Handler.Module.OnRegisterReportVariantNamesChanges(Changes);
	EndDo;
	
	// Predefined part.
	ReportsVariantsOverridable.RegisterReportVariantsKeysChanges(Changes);
	
	Changes.Columns.Report.Name = "ReportMetadata";
	Changes.Columns.Add("Report", Metadata.Catalogs.PredefinedReportsVariants.Attributes.Report.Type);
	
	// Check the replacements are correct.
	For Each Update IN Changes Do
		Update.Report = CommonUse.MetadataObjectID(Update.ReportMetadata);
		Found = Changes.FindRows(New Structure("MetadataReport, VariantOldName", Update.ReportMetadata, Update.ActualOptionName));
		If Found.Count() > 0 Then
			Conflict = Found[0];
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred while registering changes
		|of report variant name ""%1"": Relevant variant
		|name ""%2"" (old name ""%3"") is also an old name ""%4"" (relevant name ""%5"").';ru='Ошибка регистрации изменений имени
		|варианта отчета ""%1"": Актуальное имя варианта
		|""%2"" (старое имя ""%3"") так же числится как старое имя ""%4"" (актуальное имя ""%5"").'"),
				String(Update.Report),
				Update.ActualOptionName,
				Update.OldOptionName,
				Conflict.OldOptionName,
				Conflict.ActualOptionName);
		EndIf;
		Found = Changes.FindRows(New Structure("MetadataReport, VariantOldName", Update.ReportMetadata, Update.OldOptionName));
		If Found.Count() > 2 Then
			Conflict = Found[1];
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred while registring report
		|variant name ""%1"": Old variant name ""%2""
		|(relevant name ""%3"") is listed as an
		|old report variant name ""%4"" (relevant name ""%5"").';ru='Ошибка регистрации изменений имени варианта отчета ""%1"":
		|Старое имя варианта ""%2"" (актуальное имя ""%3"")
		|так же числится как старое имя 
		|варианта отчета ""%4"" (актуальное имя ""%5"").'"),
				String(Update.Report),
				Update.OldOptionName,
				Update.ActualOptionName,
				String(Conflict.ReportMetadata.Presentation()),
				Conflict.ActualOptionName);
		EndIf;
	EndDo;
	
	Return Changes;
EndFunction

// Generates reference or report type by the full name.
//
// Parameters:
//   ReportFullName - String - Report full
//       name as "Report.<ReportName>" or "ExternalReport.<ReportName>".
//
// Returns: 
//   Result - Structure -
//       * Report
//       * ReportType
//       * ReportName
//       * ReportMetadata
//       * ErrorText - String, Undefined - Error text.
//
Function GenerateInformationAboutReportByDescriptionFull(ReportFullName) Export
	Result = New Structure("Report, ReportType, ReportFullName, ReportName, ReportMetadata, ErrorText");
	Result.Report          = ReportFullName;
	Result.ReportFullName = ReportFullName;
	
	DotPosition = Find(ReportFullName, ".");
	If DotPosition = 0 Then
		Prefix = "";
		Result.ReportName = ReportFullName;
	Else
		Prefix = Left(ReportFullName, DotPosition - 1);
		Result.ReportName = Mid(ReportFullName, DotPosition + 1);
	EndIf;
	
	If Upper(Prefix) = "REPORT" Then
		Result.ReportMetadata = Metadata.Reports.Find(Result.ReportName);
		If Result.ReportMetadata = Undefined Then
			Result.ReportFullName = "ExternalReport." + Result.ReportName;
			WarningByOption(
				Undefined,
				NStr("en='Report ""%1"" is not found in application, it will be covered as external one.';ru='Отчет ""%1"" не найден в программе, он будет значиться как внешний.'"),
				ReportFullName);
		ElsIf Not AccessRight("view", Result.ReportMetadata) Then
			Result.ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='You have no rights to access report ""%1"".';ru='Недостаточно прав доступа к отчету ""%1"".'"),
				ReportFullName);
		EndIf;
	ElsIf Upper(Prefix) = "ExternalReport" Then
		// You do not need to receive metadata and checks.
	Else
		Result.ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='For report “%1” it is impossible to define type (prefix is not set).';ru='Для отчета ""%1"" невозможно определить тип (не установлен префикс).'"),
			ReportFullName);
		Return Result;
	EndIf;
	
	If Result.ReportMetadata = Undefined Then
		
		Result.Report = Result.ReportFullName;
		Result.ReportType = Enums.ReportsTypes.External;
		
		// Replace type and reference of the external report for the additional reports connected to the subsystem storage.
		If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			
			Result.Insert("ConnectedAllReports", ConnectedAllReports());
			
			ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
			ModuleAdditionalReportsAndDataProcessors.OnDefenitionTypeAndReferencesIfAdditionalReport(Result);
			
			If Result.Property("AdditionalReport") Then
				Result.ReportType = Enums.ReportsTypes.Additional;
				Result.Delete("AdditionalReport");
			EndIf;
			Result.Delete("ConnectedAllReports");
			
		EndIf;
		
	Else
		
		Result.Report = CommonUse.MetadataObjectID(Result.ReportMetadata);
		Result.ReportType = Enums.ReportsTypes.Internal;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Generates reports placing table by the configuration subsystems.
//
// Parameters:
//   Result          - Undefined - Used for recursion.
//   SubsystemParent - Undefined - Used for recursion.
//
// Returns: 
//   Result - ValueTable - Settings of reports placement by subsystems.
//       * ReportMetadata      - MetadataObject: Report.
//       * ReportFullName       - String.
//       * SubsystemMetadata - MetadataObject: Subsystem.
//       * SubsystemFullName  - String.
//
Function PlacingReportsInSubsystems(Result = Undefined, SubsystemParent = Undefined) Export
	If Result = Undefined Then
		FullNameTypeDescription = Metadata.Catalogs.MetadataObjectIDs.Attributes.FullName.Type;
		
		Result = New ValueTable;
		Result.Columns.Add("ReportMetadata",      New TypeDescription("MetadataObject"));
		Result.Columns.Add("ReportFullName",       FullNameTypeDescription);
		Result.Columns.Add("SubsystemMetadata", New TypeDescription("MetadataObject"));
		Result.Columns.Add("SubsystemFullName",  FullNameTypeDescription);
		
		SubsystemParent = Metadata;
	EndIf;
	
	// Robin of included parent subsystems.
	For Each SubsystemMetadata IN SubsystemParent.Subsystems Do
		If Not SubsystemMetadata.IncludeInCommandInterface Then
			Continue;
		EndIf;
		
		// Subsystem content
		For Each ReportMetadata IN SubsystemMetadata.Content Do
			If Not Metadata.Reports.Contains(ReportMetadata) Then
				Continue;
			EndIf;
			
			TableRow = Result.Add();
			TableRow.ReportMetadata      = ReportMetadata;
			TableRow.ReportFullName       = ReportMetadata.FullName();
			TableRow.SubsystemMetadata = SubsystemMetadata;
			TableRow.SubsystemFullName  = SubsystemMetadata.FullName();
			
		EndDo;
		
		PlacingReportsInSubsystems(Result, SubsystemMetadata);;
	EndDo;
	
	Return Result;
EndFunction

// Reset settings of the catalog predefined
//   item of the "Reports variants" catalog connected to the "Reports variants" catalog item.
//
// Parameters:
//   VariantObject - CatalogObject.ReportsVariants, FormDataStructure
//
Function ResetReport(VariantObject) Export
	If VariantObject.User
		Or VariantObject.ReportType <> Enums.ReportsTypes.Internal
		Or Not ValueIsFilled(VariantObject.PredefinedVariant) Then
		Return False;
	EndIf;
	
	VariantObject.Author = Undefined;
	VariantObject.ForAuthorOnly = False;
	VariantObject.Definition = "";
	VariantObject.Placement.Clear();
	VariantObject.VisibleByDefaultIsOverridden = False;
	Predefined = CommonUse.ObjectAttributesValues(
		VariantObject.PredefinedVariant,
		"Description, VisibleByDefault");
	FillPropertyValues(VariantObject, Predefined);
	
	Return True;
EndFunction

// Adds parent subsystems with a filter by access rights and functional options.
//
Procedure AddCurrentUserSubsystems(ParentRow, ParentMetadata = Undefined, SectionRef = Undefined) Export
	ForRootRow = (ParentMetadata = Undefined);
	ParentPriority = ?(ForRootRow, "", ParentRow.Priority);
	Subsystems = ?(ForRootRow, UsedSections(), ParentMetadata.Subsystems);
	Priority = 0;
	For Each Subsystem IN Subsystems Do
		SubsystemMetadata = ?(ForRootRow, Subsystem.Metadata, Subsystem);
		If SubsystemMetadata.IncludeInCommandInterface
			AND AccessRight("view", SubsystemMetadata)
			AND CommonUse.MetadataObjectAvailableByFunctionalOptions(SubsystemMetadata) Then
			
			Priority = Priority + 1;
			
			TreeRow = ParentRow.Rows.Add();
			TreeRow.Ref        = CommonUse.MetadataObjectID(SubsystemMetadata);
			TreeRow.Name           = SubsystemMetadata.Name;
			TreeRow.FullName     = SubsystemMetadata.FullName();
			TreeRow.Presentation = SubsystemMetadata.Presentation();
			TreeRow.SectionRef  = ?(ForRootRow, TreeRow.Ref, SectionRef);
			TreeRow.Priority     = ParentPriority + Format(Priority, "ND=4; NFD=0; NLZ=; NG=0");
			If ForRootRow Then
				TreeRow.FullPresentation = Subsystem.PanelTitle;
			ElsIf StrLen(ParentPriority) > 12 Then
				TreeRow.FullPresentation = ParentRow.Presentation + ": " + TreeRow.Presentation;
			Else
				TreeRow.FullPresentation = TreeRow.Presentation;
			EndIf;
			
			AddCurrentUserSubsystems(TreeRow, SubsystemMetadata, TreeRow.SectionRef);
		EndIf;
	EndDo;
EndProcedure

// Generates the String types description of the specified length.
Function TypeDescriptionString(StringLength = 1000) Export
	Return New TypeDescription("String", , New StringQualifiers(StringLength));
EndFunction

// Defines full rights to the subsystem data by the roles content.
Function FullRightsForVariants() Export
	Return Users.RolesAvailable("AddChangeReportsVariants");
EndFunction

// Checks whether report variant name is vacant.
Function DescriptionIsBooked(Report, Ref, Description) Export
	If Description = CommonUse.ObjectAttributeValue(Ref, "Description") Then
		Return False; // Checking is disabled as name has not changed.
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	1 AS Field1
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariants
	|WHERE
	|	ReportsVariants.Report = &Report
	|	AND ReportsVariants.Ref <> &Ref
	|	AND ReportsVariants.Description = &Description
	|	AND ReportsVariants.DeletionMark = FALSE
	|	AND Not ReportsVariants.PredefinedVariant IN (&DisabledApplicationOptions)";
	Query.SetParameter("Report",        Report);
	Query.SetParameter("Ref",       Ref);
	Query.SetParameter("Description", Description);
	Query.SetParameter("DisabledApplicationOptions", ReportsVariantsReUse.DisabledApplicationOptions());
	
	SetPrivilegedMode(True);
	Result = Not Query.Execute().IsEmpty();
	SetPrivilegedMode(False);
	
	Return Result;
EndFunction

// Checks whether report variant key is vacant.
Function VariantKeyIsBooked(Report, Ref, VariantKey) Export
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	1 AS Field1
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariants
	|WHERE
	|	ReportsVariants.Report = &Report
	|	AND ReportsVariants.Ref <> &Ref
	|	AND ReportsVariants.VariantKey = &VariantKey
	|	AND ReportsVariants.DeletionMark = FALSE";
	Query.SetParameter("Report",        Report);
	Query.SetParameter("Ref",       Ref);
	Query.SetParameter("VariantKey", VariantKey);
	
	SetPrivilegedMode(True);
	Result = Not Query.Execute().IsEmpty();
	SetPrivilegedMode(False);
	
	Return Result;
EndFunction

// Defines subsystem embedding method.
Function ConnectedAllReports() Export
	Return (Metadata.ReportsVariantsStorage <> Undefined AND Metadata.ReportsVariantsStorage.Name = "ReportsVariantsStorage");
EndFunction

// Defines whether report is connected to the subsystem.
Function ReportConnectedToStorage(ReportMetadata, ConnectedAllReports = Undefined) Export
	ConfigurationRepositoryMetadata = ReportMetadata.VariantsStorage;
	If ConfigurationRepositoryMetadata = Undefined Then
		If ConnectedAllReports = Undefined Then
			ConnectedAllReports = ConnectedAllReports();
		EndIf;
		ReportConnected = ConnectedAllReports;
	Else
		ReportConnected = (ConfigurationRepositoryMetadata = Metadata.SettingsStorages.ReportsVariantsStorage);
	EndIf;
	Return ReportConnected;
EndFunction

// Defines the method of report general form connection.
Function RepotFormIsUsedByDefault() Export
	FormMetadata = Metadata.DefaultReportForm;
	Return (FormMetadata <> Undefined AND FormMetadata = Metadata.CommonForms.ReportForm);
EndFunction

// Defines the method of report general form connection.
Function ReportFormUsedForReport(ReportMetadata, RepotFormIsUsedByDefault = Undefined) Export
	FormMetadata = ReportMetadata.DefaultForm;
	If FormMetadata = Undefined Then
		If RepotFormIsUsedByDefault = Undefined Then
			RepotFormIsUsedByDefault = RepotFormIsUsedByDefault();
		EndIf;
		ReportConnected = RepotFormIsUsedByDefault;
	Else
		ReportConnected = (FormMetadata = Metadata.CommonForms.ReportForm);
	EndIf;
	Return ReportConnected;
EndFunction

// Creates a filter by ObjectKey attribute for StandardSettingsStorageManager.Choose().
Function NewFilterByObjectKey(NamesReports) Export
	If NamesReports = "" Or NamesReports = "*" Then
		Return Undefined;
	EndIf;
	
	SeparatorPosition = Find(NamesReports, ",");
	If SeparatorPosition = 0 Then
		ObjectKey = NamesReports;
		NamesReports = "";
	Else
		ObjectKey = TrimAll(Left(NamesReports, SeparatorPosition - 1));
		NamesReports = Mid(NamesReports, SeparatorPosition + 1);
	EndIf;
	
	If Find(ObjectKey, ".") = 0 Then
		ObjectKey = "Report." + ObjectKey;
	EndIf;
	
	Return New Structure("ObjectKey", ObjectKey);
EndFunction

// Global subsystem settings.
Function GlobalSettings() Export
	Result = New Structure;
	Result.Insert("OutputReportsInsteadVariants", False);
	Result.Insert("OutputDescription", True);
	
	Result.Insert("Search", New Structure);
	Result.Search.Insert("InputHint", NStr("en='Description, field or report author';ru='Наименование, поле или автор отчета'"));
	
	Result.Insert("OtherReports", New Structure);
	Result.OtherReports.Insert("CloseAfterSelection", True);
	Result.OtherReports.Insert("ShowCheckBox", False);
	
	ReportsVariantsOverridable.DefineGlobalSettings(Result);
	
	Return Result;
EndFunction

// Reports panel global settings.
Function CommonPanelSettings() Export
	CommonSettings = CommonUse.CommonSettingsStorageImport(
		ReportsVariantsClientServer.SubsystemFullName(),
		"ReportsPanel");
	If CommonSettings = Undefined Then
		CommonSettings = New Structure("ShowNotificationOnToolTips, ShowToolTips, SearchInAllSections");
		CommonSettings.ShowNotificationOnToolTips = True;
		CommonSettings.ShowToolTips = ?(GlobalSettings().OutputDescription, 1, 0);
		CommonSettings.SearchInAllSections = False;
	Else
		CommonSettings.Insert("ShowNotificationOnToolTips", False);
	EndIf;
	Return CommonSettings;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Event log

// Write error to the events log monitor by the report variant.
Procedure ErrorByVariant(Variant, Message, Attribute1 = Undefined, Attribute2 = Undefined, Attribute3 = Undefined) Export
	WriteLogEvent(
		ReportsVariantsClientServer.SubsystemDescription(Undefined),
		EventLogLevel.Error,
		Metadata.Catalogs.ReportsVariants,
		Variant,
		StringFunctionsClientServer.PlaceParametersIntoString(
			Message,
			String(Attribute1),
			String(Attribute2),
			String(Attribute3)));
EndProcedure

// Write information in the events log monitor by the report variant.
Procedure InformationByOption(Variant, Message, Attribute1 = Undefined, Attribute2 = Undefined, Attribute3 = Undefined) Export
	WriteLogEvent(
		ReportsVariantsClientServer.SubsystemDescription(Undefined),
		EventLogLevel.Information,
		Metadata.Catalogs.ReportsVariants,
		Variant,
		StringFunctionsClientServer.PlaceParametersIntoString(
			Message,
			String(Attribute1),
			String(Attribute2),
			String(Attribute3)));
EndProcedure

// Warning record in the events log monitor by the report variant.
Procedure WarningByOption(Variant, Message, Attribute1 = Undefined, Attribute2 = Undefined, Attribute3 = Undefined) Export
	WriteLogEvent(
		ReportsVariantsClientServer.SubsystemDescription(Undefined),
		EventLogLevel.Warning,
		Metadata.Catalogs.ReportsVariants,
		Variant,
		StringFunctionsClientServer.PlaceParametersIntoString(
			Message,
			String(Attribute1),
			String(Attribute2),
			String(Attribute3)));
EndProcedure

// Writes a procedure start event to the events log monitor and opens transaction.
Procedure ProcedureLaunch(ProcedureRepresentation)
	InformationByOption(Undefined, NStr("en='Launching procedure ""%1"".';ru='Запуск процедуры ""%1"".'"), ProcedureRepresentation);
	BeginTransaction();
EndProcedure

// Writes procedure end event to the events log monitor and writes the transaction.
Procedure ProcedureCompletion(ProcedureRepresentation, Changed = Undefined)
	CommitTransaction();
	Text = NStr("en='End the procedure ""%1"".';ru='Завершение процедуры ""%1"".'");
	If Changed <> Undefined Then
		Text = Text + " " + NStr("en='%2 objects are changed.';ru='Изменено %2 объектов.'");
	EndIf;
	InformationByOption(Undefined, Text, ProcedureRepresentation, Changed);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Standard events handlers.

// Delete personal reports variants while deleting user.
Procedure OnDeleteUser(UserObject, Cancel) Export
	If UserObject.IsNew()
		Or UserObject.DataExchange.Load
		Or Cancel
		Or Not UserObject.DeletionMark Then
		Return;
	EndIf;
	
	// Set deletion mark of user personal variants.
	QueryText =
	"SELECT
	|	ReportsVariants.Ref
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariants
	|WHERE
	|	ReportsVariants.Author = &UserRef
	|	AND ReportsVariants.DeletionMark = FALSE
	|	AND ReportsVariants.ForAuthorOnly = TRUE";
	
	Query = New Query;
	Query.SetParameter("UserRef", UserObject.Ref);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VariantObject = Selection.Ref.GetObject();
		VariantObject.AdditionalProperties.Insert("IndexSchema", False);
		VariantObject.SetDeletionMark(True);
	EndDo;
EndProcedure

// Delete subsystems references before you delete them.
Procedure BeforeMetadataObjectIdentifierDeletion(MetadataObjectIdentifierObject, Cancel) Export
	If MetadataObjectIdentifierObject.DataExchange.Load Then
		Return;
	EndIf;
	
	Subsystem = MetadataObjectIdentifierObject.Ref;
	
	QueryText =
	"SELECT DISTINCT
	|	ReportsVariants.Ref
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariants
	|WHERE
	|	ReportsVariants.Placement.Subsystem = &Subsystem";
	
	Query = New Query;
	Query.SetParameter("Subsystem", Subsystem);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VariantObject = Selection.Ref.GetObject();
		
		Found = VariantObject.Placement.FindRows(New Structure("Subsystem", Subsystem));
		For Each TableRow IN Found Do
			VariantObject.Placement.Delete(TableRow);
		EndDo;
		
		VariantObject.Write();
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Info base update.

// [*] Actualizes undivided data: the PredefinedReportsVariants catalog
// and the ReportVariantsParameters constant
Procedure UpdateCommonData(UpdateParameters) Export
	
	////////////////////////////////////////////////////////////////////////////////
	// Executed only for the predefined report variants.
	// Update plan:
	
	Cache = New Structure;
	Cache.Insert("UsedSections", UsedSections());
	Cache.Insert("ConnectedAllReports", ConnectedAllReports());
	Cache.Insert("OptionsTree", ReportVariantsTreesSettingsConfigurations());
	Cache.Insert("RefreshAreas", False);
	
	////////////////////////////////////////////////////////////////////////////////
	// 1. Replace outdated reports variants keys to the relevant ones.
	UpdateKeysFixed(Cache);
	
	////////////////////////////////////////////////////////////////////////////////
	// 2. Actualize predefined reports variants
	//    and rewrite constant where binds to functional options are stored.
	UpdateSettingsOfPredefined(Cache);
	
	////////////////////////////////////////////////////////////////////////////////
	// 3. Set variants deletion mark of deleted reports.
	MarkOnDeletionDeletedReportVariants(Cache, True);
	
	////////////////////////////////////////////////////////////////////////////////
	// 4. Update separated data in the service model.
	If Cache.RefreshAreas AND CommonUseReUse.DataSeparationEnabled() Then
		Handler = UpdateParameters.SeparatedHandlers.Add();
		Handler.PerformModes = "Promptly";
		Handler.Version    = "*";
		Handler.Procedure = "ReportsVariants.UpdateDividedData";
		Handler.Priority = 70;
	EndIf;
	
EndProcedure

// [*] Actualizes separated data: ReportsVariants catalog.
Procedure UpdateDividedData() Export
	
	////////////////////////////////////////////////////////////////////////////////
	// Update plan:
	
	////////////////////////////////////////////////////////////////////////////////
	// 1. Actualize separated reports variants.
	UpdateContentAreas();
	
	////////////////////////////////////////////////////////////////////////////////
	// 2. Set variants deletion mark of deleted reports.
	MarkOnDeletionDeletedReportVariants(Undefined, False);
	
EndProcedure

// [2.1.1.1] Transfers "Reports variants" catalog data for edition 2.1.
Procedure NavigateToVersion21() Export
	ProcedureRepresentation = NStr("en='Navigate to version 2.1';ru='Перейти к редакции 2.1'");
	ProcedureLaunch(ProcedureRepresentation);
	
	QueryText =
	"SELECT DISTINCT
	|	ReportsVariants.Ref,
	|	ReportsVariants.DeleteObjectKey AS ReportFullName
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariants
	|WHERE
	|	ReportsVariants.DeleteObjectKey <> """"";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		// Generate information about report.
		ReportInformation = GenerateInformationAboutReportByDescriptionFull(Selection.ReportFullName);
		
		// Check result
		If TypeOf(ReportInformation.ErrorText) = Type("String") Then
			ErrorByVariant(Selection.Ref, ReportInformation.ErrorText);
			Continue;
		EndIf;
		
		VariantObject = Selection.Ref.GetObject();
		
		If VariantObject.ReportType = Enums.ReportsTypes.DeleteCustom
			Or VariantObject.ReportType = Enums.ReportsTypes.External Then
			VariantObject.User = True;
		Else
			VariantObject.User = False;
		EndIf;
		
		VariantObject.Report = ReportInformation.Report;
		VariantObject.ReportType = ReportInformation.ReportType;
		
		If ReportInformation.ReportType = Enums.ReportsTypes.External Then
			// Set external report variant settings specific to all external report variants.
			// All variants of the external reports
			// are user ones as the predefined variants of
			// external reports are not registered in the system and counted each time dynamically.
			VariantObject.User = True;
			
			// External reports variants can not be opened from reports panel.
			VariantObject.Placement.Clear();
			
		Else
			
			// Replace subsystems full names to "Metadata objects identifiers" catalog references.
			Edition21BringSettingsBySections(VariantObject);
			
			// Transfer user settings from the tabular section to the information register.
			Edition21TransferUserSettingsToRegister(VariantObject);
			
		EndIf;
		
		// Variants are supplied without author.
		If Not VariantObject.User Then
			VariantObject.Author = Undefined;
		EndIf;
		
		VariantObject.DeleteObjectKey = "";
		VariantObject.DeleteObjectPresentation = "";
		VariantObject.DeleteQuickAccessExceptions.Clear();
		WritePredefined(VariantObject);
	EndDo;
	
	ProcedureCompletion(ProcedureRepresentation);
EndProcedure

// [2.1.3.6] Fills out references of predetermined items of catalog "Reports variants".
Procedure FillRefsOfPredefined() Export
	ProcedureRepresentation = NStr("en='Fill in the links of the predefined report variants';ru='Заполнить ссылки предопределенных вариантов отчетов'");
	ProcedureLaunch(ProcedureRepresentation);
	
	// Generate table of the variants keys to relevant ones replacements.
	Changes = KeysChanges();
	
	// Receive reports variants refs for keys
	//   replacement by deleting from the replacements list
	//   those reports variants, relevant keys
	//   of which are already registered or old keys that are no longer occupied.
	QueryText =
	"SELECT
	|	Changes.Report AS Report,
	|	Changes.OldOptionName AS OldOptionName,
	|	Changes.ActualOptionName AS ActualOptionName
	|INTO ttChanges
	|FROM
	|	&Changes AS Changes
	|
	|INDEX BY
	|	Report,
	|	OldOptionName,
	|	ActualOptionName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ReportsVariants.Ref AS Ref,
	|	CAST(ReportsVariants.Report AS Catalog.MetadataObjectIDs) AS Report,
	|	ISNULL(ttChanges.ActualOptionName, ReportsVariants.VariantKey) AS CurrentVariantKey
	|INTO TTTopical
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariants
	|		LEFT JOIN ttChanges AS ttChanges
	|		ON ReportsVariants.Report = ttChanges.Report
	|			AND ReportsVariants.VariantKey = ttChanges.OldOptionName
	|WHERE
	|	ReportsVariants.User = FALSE
	|	AND ReportsVariants.ReportType = &ReportType
	|	AND ReportsVariants.DeletionMark = FALSE
	|	AND ReportsVariants.PredefinedVariant = &EmptyPredefined
	|
	|INDEX BY
	|	Report,
	|	CurrentVariantKey,
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TTTopical.Ref,
	|	PredefinedReportsVariants.Description,
	|	PredefinedReportsVariants.VariantKey,
	|	ISNULL(PredefinedReportsVariants.Ref, UNDEFINED) AS PredefinedVariant
	|FROM
	|	TTTopical AS TTTopical
	|		LEFT JOIN Catalog.PredefinedReportsVariants AS PredefinedReportsVariants
	|		ON TTTopical.Report = PredefinedReportsVariants.Report
	|			AND TTTopical.CurrentVariantKey = PredefinedReportsVariants.VariantKey";
	
	Query = New Query;
	Query.SetParameter("Changes", Changes);
	Query.SetParameter("ReportType", Enums.ReportsTypes.Internal);
	Query.SetParameter("EmptyPredefined", Catalogs.PredefinedReportsVariants.EmptyRef());
	Query.Text = QueryText;
	
	// Replace variants names to references.
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VariantObject = Selection.Ref.GetObject();
		VariantObject.AdditionalProperties.Insert("PredefinedOnesFilling", True);
		VariantObject.AdditionalProperties.Insert("IndexSchema", False);
		If ValueIsFilled(Selection.PredefinedVariant) Then
			FillPropertyValues(VariantObject, Selection, "Description, VariantKey, PredefinedVariant");
			Found = VariantObject.Placement.FindRows(New Structure("DeleteFixed", True));
			For Each TableRow IN Found Do
				VariantObject.Placement.Delete(TableRow);
			EndDo;
			VariantObject.Definition = "";
			InfobaseUpdate.WriteData(VariantObject);
		Else
			VariantObject.SetDeletionMark(True);
		EndIf;
	EndDo;
	
	ProcedureCompletion(ProcedureRepresentation);
	
EndProcedure

// Partial search index of the predefined reports variants. - only by changes in the variants settings.
Procedure DeferredGeneralDataIncrementalUpdate(Parameters = Undefined) Export
	DeferredGeneralDataUpdate(False);
EndProcedure

// Full update of search index of the predefined reports variants.
Procedure DeferredGeneralDataFullUpdate(Parameters = Undefined) Export
	DeferredGeneralDataUpdate(True);
EndProcedure

// Update search index of the predefined reports variants.
Procedure DeferredGeneralDataUpdate(Full)
	If Not UndividedDataIndexationAllowed() Then
		Return;
	EndIf;
	If Full Then
		ProcedureRepresentation = NStr("en='Postponed general data update (full)';ru='Отложенное обновление общих данных (полное)'");
	Else
		ProcedureRepresentation = NStr("en='Postponed update of the general data (by changes)';ru='Отложенное обновление общих данных (по изменениям)'");
	EndIf;
	ProcedureLaunch(ProcedureRepresentation);
	
	OptionsTree = ReportVariantsTreesSettingsConfigurations();
	
	OldInformation = New Structure("SettingsHash, FieldNames, ParametersAndFiltersNames");
	Query = New Query("SELECT Ref FROM Catalog.PredefinedReportsVariants WHERE DeletionMark = FALSE");
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VariantObject = Selection.Ref.GetObject();
		VariantObject.AdditionalProperties.Insert("OptionsTree", OptionsTree);
		FillPropertyValues(OldInformation, VariantObject);
		VariantObject.FieldNames = "";
		VariantObject.ParametersAndFiltersNames = "";
		If Full Then // Reindex forcefully without checking hash amount.
			VariantObject.AdditionalProperties.Insert("IndexSchema", True);
		EndIf;
		SchemaIndexed = IndexSchemaContent(VariantObject);
		If Full Or (SchemaIndexed
			AND PredefinedSearchSettingsChanged(VariantObject, OldInformation)) Then
			WritePredefined(VariantObject);
		EndIf;
	EndDo;
	
	ProcedureCompletion(ProcedureRepresentation);
EndProcedure

// Full update of reports variants search index.
Procedure DeferredSeparatedDataFullUpdate(Parameters = Undefined) Export
	ProcedureRepresentation = NStr("en='Deferred separated data update (full)';ru='Отложенное обновление разделенных данных (полное)'");
	ProcedureLaunch(ProcedureRepresentation);
	
	CacheReports = New Map;
	
	QueryText =
	"SELECT
	|	Table.Ref,
	|	Table.Report
	|FROM
	|	Catalog.ReportsVariants AS Table
	|WHERE
	|	(Table.PredefinedVariant = &EmptyRef
	|			OR Table.PredefinedVariant = UNDEFINED
	|			OR Table.PredefinedVariant.DeletionMark = FALSE)";
	
	Query = New Query(QueryText);
	Query.SetParameter("EmptyRef", Catalogs.PredefinedReportsVariants.EmptyRef());
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ReportObject = CacheReports.Get(Selection.Report); // Reading cache.
		If ReportObject = Undefined Then // Writing to cache.
			ConnectionResult = ConnectReportObject(Selection.Report);
			If ConnectionResult.Connected Then
				ReportObject = ConnectionResult.Object;
			Else // The report is not found.
				ErrorByVariant(Selection.Ref, ConnectionResult.Errors);
				ReportObject = "";
			EndIf;
			CacheReports.Insert(Selection.Report, ReportObject);
		EndIf;
		If ReportObject = "" Then
			Continue;
		EndIf;
		
		VariantObject = Selection.Ref.GetObject();
		VariantObject.AdditionalProperties.Insert("IndexSchema", True);
		VariantObject.AdditionalProperties.Insert("ReportObject", ReportObject);
		WritePredefined(VariantObject);
	EndDo;
	
	ProcedureCompletion(ProcedureRepresentation);
EndProcedure

// [2.2.3.30] Decreases quick settings quantity in the report user variants down to 2.
Procedure ReduceQuickSettingsQuantity(IncomingParameters = Undefined) Export
	ProcedureRepresentation = NStr("en='Decrease the quantity of quick settings in reports';ru='Сокращение количества быстрых настроек в отчетах'");
	ProcedureLaunch(ProcedureRepresentation);
	
	// Read information from the previous start with errors.
	Parameters = CommonUse.CommonSettingsStorageImport(
		ReportsVariantsClientServer.SubsystemFullName(),
		"ReduceQuickSettingsQuantity"
	);
	Query = New Query;
	If Parameters = Undefined Then
		Query.Text = "SELECT Ref, Report FROM Catalog.ReportsVariants WHERE User AND ReportType <> &External";
		Query.SetParameter("External", Enums.ReportsTypes.External);
		TryNumber = 1;
	Else
		Query.Text = "SELECT Ref, Report FROM Catalog.ReportsVariants WHERE Ref IN (&VariantsWithErrors)";
		Query.SetParameter("VariantsWithErrors", Parameters.VariantsWithErrors);
		TryNumber = Parameters.TryNumber + 1;
	EndIf;
	ReportsTable = Query.Execute().Unload();
	
	Writed = 0;
	errors = 0;
	CacheReports = New Map;
	UseByDefault = RepotFormIsUsedByDefault();
	VariantsWithErrors = New Array;
	
	For Each TableRow IN ReportsTable Do
		ReportObject = CacheReports.Get(TableRow.Report); // Reading cache.
		If ReportObject = Undefined Then // Writing to cache.
			ConnectionResult = ConnectReportObject(TableRow.Report);
			If ConnectionResult.Connected Then
				ReportObject = ConnectionResult.Object;
				ReportMetadata = ConnectionResult.Metadata;
				If Not ReportFormUsedForReport(ReportMetadata, UseByDefault) Then
					// Report is not connected to a report general form.
					// Quantity of quick settings should be decreased using the applied method.
					ReportObject = "";
				EndIf;
			Else // The report is not found.
				ErrorByVariant(TableRow.Ref, ConnectionResult.Errors);
				ReportObject = "";
			EndIf;
			CacheReports.Insert(TableRow.Report, ReportObject);
		EndIf;
		If ReportObject = "" Then
			Continue;
		EndIf;
		
		VariantObject = TableRow.Ref.GetObject();
		
		ErrorInfo = Undefined;
		Try
			RequiredRecord = DecreaseQuickSettingsQuantity(VariantObject, ReportObject);
		Except
			ErrorInfo = ErrorInfo();
			RequiredRecord = False;
		EndTry;
		If ErrorInfo <> Undefined Then // Problem detected.
			ErrorText = NStr("en='Variant ""%1"" of report ""%2"":';ru='Вариант ""%1"" отчета ""%2"":'")
			+ Chars.LF + NStr("en='An error occurred while reducing a number of quick custom settings:';ru='При уменьшении количества быстрых настроек пользовательского возникла ошибка:'")
			+ Chars.LF + DetailErrorDescription(ErrorInfo);
			ErrorByVariant(VariantObject.Ref, ErrorText, VariantObject.VariantKey, VariantObject.Report);
			VariantsWithErrors.Add(VariantObject.Ref);
			errors = errors + 1;
		EndIf;
		
		If RequiredRecord Then
			VariantObject.AdditionalProperties.Insert("IndexSchema", False);
			VariantObject.AdditionalProperties.Insert("ReportObject", ReportObject);
			WritePredefined(VariantObject);
			Writed = Writed + 1;
		EndIf;
	EndDo;
	
	If errors > 0 Then
		// Information record for the next start.
		Parameters = New Structure;
		Parameters.Insert("TryNumber", TryNumber);
		Parameters.Insert("VariantsWithErrors", VariantsWithErrors);
		
		CommonUse.CommonSettingsStorageSave(
			ReportsVariantsClientServer.SubsystemFullName(),
			"ReduceQuickSettingsQuantity",
			Parameters
		);
	ElsIf TryNumber > 1 Then
		// Delete information from the previous starts.
		CommonUse.CommonSettingsStorageDelete(
			ReportsVariantsClientServer.SubsystemFullName(),
			"ReduceQuickSettingsQuantity",
			UserName()
		);
	EndIf;
	
	ProcedureCompletion(ProcedureRepresentation, Writed);
	
	If errors > 0 AND TryNumber <= 30 Then
		// Next start should take place.
		ErrorText = ProcedureRepresentation + ":"
			+ Chars.LF + NStr("en='Unable to decrease the quantity of quick settings %1 of reports.';ru='Не удалось уменьшить количество быстрых настроек %1 отчетов.'");
		ErrorText = StrReplace(ErrorText, "%1", errors);
		Raise ErrorText;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Updating the info base / Initial filling and updating catalogs.

// Replace old reports variants key to the relevant ones.
Procedure UpdateKeysFixed(Cache)
	ProcedureRepresentation = NStr("en='Update the report variant keys';ru='Обновить ключи вариантов отчетов'");
	ProcedureLaunch(ProcedureRepresentation);
	
	// Generate table of the variants keys to relevant ones replacements.
	Changes = KeysChanges();
	
	// Receive reports variants refs for keys
	//   replacement by deleting from the replacements list
	//   those reports variants, relevant keys
	//   of which are already registered or old keys that are no longer occupied.
	QueryText =
	"SELECT
	|	Changes.Report,
	|	Changes.OldOptionName,
	|	Changes.ActualOptionName
	|INTO ttChanges
	|FROM
	|	&Changes AS Changes
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ttChanges.Report,
	|	ttChanges.ActualOptionName,
	|	ReportsVariantsOld.Ref
	|FROM
	|	ttChanges AS ttChanges
	|		LEFT JOIN Catalog.PredefinedReportsVariants AS ReportsVariantsActual
	|		ON ttChanges.Report = ReportsVariantsActual.Report
	|			AND ttChanges.ActualOptionName = ReportsVariantsActual.VariantKey
	|		LEFT JOIN Catalog.PredefinedReportsVariants AS ReportsVariantsOld
	|		ON ttChanges.Report = ReportsVariantsOld.Report
	|			AND ttChanges.OldOptionName = ReportsVariantsOld.VariantKey
	|WHERE
	|	ReportsVariantsActual.Ref IS NULL 
	|	AND Not ReportsVariantsOld.Ref IS NULL ";
	
	Query = New Query;
	Query.SetParameter("Changes", Changes);
	Query.Text = QueryText;
	
	// Replace variants old names to the relevant ones.
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Cache.RefreshAreas = True;
		VariantObject = Selection.Ref.GetObject();
		VariantObject.VariantKey = Selection.ActualOptionName;
		WritePredefined(VariantObject);
	EndDo;
	
	ProcedureCompletion(ProcedureRepresentation);
EndProcedure

// Actualize predefined reports variants.
Procedure UpdateSettingsOfPredefined(Cache)
	ProcedureRepresentation = NStr("en='Refresh predefined';ru='Обновить предопределенные'");
	ProcedureLaunch(ProcedureRepresentation);
	
	TableFunctionalOptions = New ValueTable;
	TableFunctionalOptions.Columns.Add("Report", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	TableFunctionalOptions.Columns.Add("PredefinedVariant", New TypeDescription("CatalogRef.PredefinedReportsVariants"));
	TableFunctionalOptions.Columns.Add("FunctionalOptionName", New TypeDescription("String"));
	Cache.Insert("TableFunctionalOptions", TableFunctionalOptions);
	
	ReportsWithSettingsList = New ValueList;
	
	Cache.OptionsTree.Columns.Add("FoundInDatabase", New TypeDescription("Boolean"));
	Cache.OptionsTree.Columns.Add("VariantFromBase", New TypeDescription("ValueTableRow"));
	Cache.OptionsTree.Columns.Add("VarianParent", New TypeDescription("CatalogRef.PredefinedReportsVariants"));
	OptionSearch = New Structure("Report, VariantKey, FoundInDatabase, IsOption", , , False, True);
	EmptyRef = Catalogs.PredefinedReportsVariants.EmptyRef();
	
	// Match information from base and the one from metadata and mark for deletion the old objects from base.
	Query = New Query("SELECT * FROM Catalog.PredefinedReportsVariants ORDER BY DeletionMark");
	TablePredetermined = Query.Execute().Unload();
	For Each VariantFromBase IN TablePredetermined Do
		FillPropertyValues(OptionSearch, VariantFromBase, "Report, VariantKey");
		Found = Cache.OptionsTree.Rows.FindRows(OptionSearch, True);
		If Found.Count() = 0 Then
			If VariantFromBase.DeletionMark AND VariantFromBase.Parent <> EmptyRef Then
				Continue; // The action is not required.
			EndIf;
			VariantObject = VariantFromBase.Ref.GetObject();
			VariantObject.DeletionMark = True;
			VariantObject.Parent = EmptyRef;
			WritePredefined(VariantObject);
			Cache.RefreshAreas = True;
		Else
			VariantDesc = Found[0];
			FillDetailsRowsOption(VariantDesc);
			VariantDesc.FoundInDatabase = True;
			VariantDesc.VariantFromBase = VariantFromBase;
		EndIf;
	EndDo;
	
	// Add/update information in the data base.
	For Each ReportDescription IN Cache.OptionsTree.Rows Do
		DefaultVariantRef = EmptyRef;
		DefaultVariant = ReportDescription.DefaultVariant;
		If TypeOf(DefaultVariant) = Type("ValueTreeRow") Then
			FillDetailsRowsOption(DefaultVariant);
			DefaultVariant.VarianParent = EmptyRef;
			DefaultVariantRef = UpdatePredefined(Cache, DefaultVariant); // Variant without parent.
		EndIf;
		If ReportDescription.DefineFormSettings Then
			ReportsWithSettingsList.Add(ReportDescription.Report);
		EndIf;
		For Each VariantDesc IN ReportDescription.Rows Do
			FillDetailsRowsOption(VariantDesc);
			If VariantDesc = DefaultVariant Then
				VariantRef = DefaultVariantRef;
			Else
				VariantDesc.VarianParent = DefaultVariantRef;
				VariantRef = UpdatePredefined(Cache, VariantDesc);
			EndIf;
			For Each FunctionalOptionName IN VariantDesc.FunctionalOptions Do
				LinkFromFunctionalOption = TableFunctionalOptions.Add();
				LinkFromFunctionalOption.Report                   = VariantDesc.Report;
				LinkFromFunctionalOption.PredefinedVariant = VariantRef;
				LinkFromFunctionalOption.FunctionalOptionName  = FunctionalOptionName;
			EndDo;
		EndDo;
	EndDo;
	
	// Rewrite constant only if update handler is launched "for writing" (in the exclusive mode).
	TableFunctionalOptions.Sort("Report, PredefinedVariant, FunctionalOptionName");
	ReportsWithSettingsList.SortByValue();
	ReportsWithSettings = ReportsWithSettingsList.UnloadValues();
	
	NewValue = New Structure;
	NewValue.Insert("TableFunctionalOptions", TableFunctionalOptions);
	NewValue.Insert("ReportsWithSettings", ReportsWithSettings);
	
	OldValue = Constants.ReportVariantParameters.Get().Get();
	If CommonUse.ValueToXMLString(NewValue) <> CommonUse.ValueToXMLString(OldValue) Then
		ConstantObject = Constants.ReportVariantParameters.CreateValueManager();
		ConstantObject.Value = New ValueStorage(NewValue, New Deflation(9));
		InfobaseUpdate.WriteData(ConstantObject, False, False);
	EndIf;
	
	ProcedureCompletion(ProcedureRepresentation);
EndProcedure

// Writes variant settings to the catalog data.
Function UpdatePredefined(Cache, VariantDesc)
	If VariantDesc.FoundInDatabase Then
		VariantFromBase = VariantDesc.VariantFromBase;
		If ChangedKeySettingsPredefined(VariantDesc, VariantFromBase) Then
			Cache.RefreshAreas = True; // Rewrite with the separated data update.
		ElsIf ChangedPredefinedMinorSettings(VariantDesc, VariantFromBase) Then
			// Rewrite without updating separated data.
		Else
			Return VariantFromBase.Ref;
		EndIf;
		
		VariantObject = VariantDesc.VariantFromBase.Ref.GetObject();
		VariantObject.Placement.Clear();
		If VariantObject.DeletionMark Then
			VariantObject.DeletionMark = False;
		EndIf;
	Else
		Cache.RefreshAreas = True; // Register new.
		VariantObject = Catalogs.PredefinedReportsVariants.CreateItem();
	EndIf;
	
	FillPropertyValues(VariantObject, VariantDesc, "Report, VariantKey, Description, Enabled, VisibleByDefault, Definition, GroupByReport");
	
	VariantObject.Parent = VariantDesc.VarianParent;
	
	For Each KeyAndValue IN VariantDesc.Placement Do
		RowOfPlacement = VariantObject.Placement.Add();
		RowOfPlacement.Subsystem = CommonUse.MetadataObjectID(KeyAndValue.Key);
		RowOfPlacement.Important  = (Lower(KeyAndValue.Value) = Lower("Important"));
		RowOfPlacement.SeeAlso = (Lower(KeyAndValue.Value) = Lower("SeeAlso"));
	EndDo;
	
	WritePredefined(VariantObject);
	
	Return VariantObject.Ref;
EndFunction

// Determines whether key settings of the predetermined report variant changed.
Function ChangedKeySettingsPredefined(VariantDesc, VariantFromBase)
	If VariantFromBase.DeletionMark = True // Description is received => it is required to clear mark for deletion.
		Or VariantFromBase.Description <> VariantDesc.Description
		Or VariantFromBase.Parent <> VariantDesc.VarianParent
		Or VariantFromBase.VisibleByDefault <> VariantDesc.VisibleByDefault Then
		Return True;
	Else
		Return False;
	EndIf;
EndFunction

// Determines whether auxiliary settings of the predetermined report variant changed.
Function ChangedPredefinedMinorSettings(VariantDesc, VariantFromBase)
	// Header
	If VariantFromBase.Enabled <> VariantDesc.Enabled
		Or VariantFromBase.Definition <> VariantDesc.Definition
		Or VariantFromBase.GroupByReport <> VariantDesc.GroupByReport Then
		Return True;
	EndIf;
	
	// Table "Placement"
	PlacementTable = VariantFromBase.Placement;
	If PlacementTable.Count() <> VariantDesc.Placement.Count() Then
		Return True;
	EndIf;
	
	For Each KeyAndValue IN VariantDesc.Placement Do
		Subsystem = CommonUse.MetadataObjectID(KeyAndValue.Key);
		RowOfPlacement = PlacementTable.Find(Subsystem, "Subsystem");
		If RowOfPlacement = Undefined
			Or RowOfPlacement.Important <> (Lower(KeyAndValue.Value) = Lower("Important"))
			Or RowOfPlacement.SeeAlso <> (Lower(KeyAndValue.Value) = Lower("SeeAlso")) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
EndFunction

// Defines whether search settings of the report predefined variant are changed.
Function PredefinedSearchSettingsChanged(VariantFromBase, OldInformation)
	If VariantFromBase.SettingsHash <> OldInformation.SettingsHash
		Or VariantFromBase.FieldNames <> OldInformation.FieldNames
		Or VariantFromBase.ParametersAndFiltersNames <> OldInformation.ParametersAndFiltersNames Then
		Return True;
	Else
		Return False;
	EndIf;
EndFunction

// Makes the divided data compliant to the undivided data.
Procedure UpdateContentAreas()
	
	ProcedureRepresentation = NStr("en='Update the separated report variants';ru='Обновить разделенные вариантов отчетов'");
	ProcedureLaunch(ProcedureRepresentation);
	
	// Update predefined variants information.
	QueryText =
	"SELECT
	|	PredefinedReportsVariants.Ref AS PredefinedVariant,
	|	PredefinedReportsVariants.Description AS Description,
	|	PredefinedReportsVariants.Report AS Report,
	|	PredefinedReportsVariants.GroupByReport AS GroupByReport,
	|	PredefinedReportsVariants.VariantKey AS VariantKey,
	|	PredefinedReportsVariants.VisibleByDefault AS VisibleByDefault,
	|	PredefinedReportsVariants.Parent AS Parent
	|INTO TTPredefined
	|FROM
	|	Catalog.PredefinedReportsVariants AS PredefinedReportsVariants
	|WHERE
	|	PredefinedReportsVariants.DeletionMark = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReportsVariants.Ref,
	|	ReportsVariants.DeletionMark,
	|	ReportsVariants.Report,
	|	ReportsVariants.ReportType,
	|	ReportsVariants.VariantKey,
	|	ReportsVariants.Description,
	|	ReportsVariants.PredefinedVariant,
	|	ReportsVariants.VisibleByDefault,
	|	ReportsVariants.Parent
	|INTO vtReportsVariants
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariants
	|WHERE
	|	(ReportsVariants.ReportType = VALUE(Enum.ReportsTypes.Internal)
	|			OR VALUETYPE(ReportsVariants.Report) = Type(Catalog.MetadataObjectIDs))
	|	AND ReportsVariants.User = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN TTPredefined.PredefinedVariant IS NULL 
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS SetDeletionMark,
	|	CASE
	|		WHEN vtReportsVariants.Ref IS NULL 
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS CreateNew,
	|	TTPredefined.PredefinedVariant AS PredefinedVariant,
	|	TTPredefined.Description AS Description,
	|	TTPredefined.Report AS Report,
	|	TTPredefined.VariantKey AS VariantKey,
	|	TTPredefined.GroupByReport AS GroupByReport,
	|	TTPredefined.Parent AS PredefinedVariantParent,
	|	TTPredefined.VisibleByDefault AS VisibleByDefault,
	|	vtReportsVariants.Ref AS AttributeRef,
	|	vtReportsVariants.Parent AS AttributeParent,
	|	vtReportsVariants.ReportType AS AttributeReportType,
	|	vtReportsVariants.Report AS AttributeReport,
	|	vtReportsVariants.VariantKey AS AttributeVariantKey,
	|	vtReportsVariants.Description AS AttributeDescription,
	|	vtReportsVariants.PredefinedVariant AS AttributePredefinedVariant,
	|	vtReportsVariants.DeletionMark AS AttributeDeletionMark,
	|	vtReportsVariants.VisibleByDefault AS AttributeVisibleByDefault
	|FROM
	|	vtReportsVariants AS vtReportsVariants
	|		Full JOIN TTPredefined AS TTPredefined
	|		ON vtReportsVariants.PredefinedVariant = TTPredefined.PredefinedVariant";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Cache = New Structure;
	Cache.Insert("EmptyRef", Catalogs.ReportsVariants.EmptyRef());
	Cache.Insert("SearchParents", New Map);
	Cache.Insert("ProcessedPredefined", New Array);
	Cache.Insert("MainVariants", New ValueTable);
	Cache.MainVariants.Columns.Add("Report", Metadata.Catalogs.ReportsVariants.Attributes.Report.Type);
	Cache.MainVariants.Columns.Add("Variant", New TypeDescription("CatalogRef.ReportsVariants"));
	
	Patterns = New Structure;
	
	Patterns.Insert("SettingMarkDeletion", New Structure);
	Patterns.SettingMarkDeletion.Insert("Parent", Cache.EmptyRef);
	Patterns.SettingMarkDeletion.Insert("DeletionMark", True);
	
	Patterns.Insert("UpdateInformation", New Structure);
	Patterns.UpdateInformation.Insert("ReportType", Enums.ReportsTypes.Internal);
	Patterns.UpdateInformation.Insert("DeletionMark", False);
	Patterns.UpdateInformation.Insert("Parent", Undefined);
	Patterns.UpdateInformation.Insert("Description", Undefined);
	Patterns.UpdateInformation.Insert("Report", Undefined);
	Patterns.UpdateInformation.Insert("VariantKey", Undefined);
	Patterns.UpdateInformation.Insert("PredefinedVariant", Undefined);
	Patterns.UpdateInformation.Insert("VisibleByDefault", Undefined);
	
	CompositeTablePredefined = Query.Execute().Unload();
	CompositeTablePredefined.Columns.Add("Processed", New TypeDescription("Boolean"));
	CompositeTablePredefined.Columns.Add("Parent", New TypeDescription("CatalogRef.ReportsVariants"));
	
	// Update main predefined variants (without parent).
	Search = New Structure("PredefinedVariantParent, SetDeletionMark", Catalogs.PredefinedReportsVariants.EmptyRef(), False);
	Found = CompositeTablePredefined.FindRows(Search);
	For Each TableRow IN Found Do
		If TableRow.Processed Then
			Continue;
		EndIf;
		If Cache.ProcessedPredefined.Find(TableRow.PredefinedVariant) <> Undefined Then
			TableRow.SetDeletionMark = True;
		EndIf;
		
		TableRow.Parent = Cache.EmptyRef;
		UpdateSeparatedPredefined(Cache, Patterns, TableRow);
		
		If Not TableRow.SetDeletionMark
			AND TableRow.GroupByReport
			AND Cache.SearchParents.Get(TableRow.Report) = Undefined Then
			Cache.SearchParents.Insert(TableRow.Report, TableRow.AttributeRef);
			DefaultVariant = Cache.MainVariants.Add();
			DefaultVariant.Report   = TableRow.Report;
			DefaultVariant.Variant = TableRow.AttributeRef;
		EndIf;
	EndDo;
	
	// Update all remaining predefined variants (subordinate).
	CompositeTablePredefined.Sort("SetDeletionMark Asc");
	For Each TableRow IN CompositeTablePredefined Do
		If TableRow.Processed Then
			Continue;
		EndIf;
		If Cache.ProcessedPredefined.Find(TableRow.PredefinedVariant) <> Undefined Then
			TableRow.SetDeletionMark = True;
		EndIf;
		If TableRow.SetDeletionMark Then
			ParentRef = Cache.EmptyRef;
		Else
			ParentRef = Cache.SearchParents.Get(TableRow.Report);
		EndIf;
		
		TableRow.Parent = ParentRef;
		UpdateSeparatedPredefined(Cache, Patterns, TableRow);
	EndDo;
	
	// Update user variants parents.
	QueryText =
	"SELECT
	|	MainReportsVariants.Report,
	|	MainReportsVariants.Variant
	|INTO ttMaster
	|FROM
	|	&MainReportsVariants AS MainReportsVariants
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReportsVariants.Ref,
	|	ttMaster.Variant AS Parent
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariants
	|		INNER JOIN ttMaster AS ttMaster
	|		ON ReportsVariants.Report = ttMaster.Report
	|			AND ReportsVariants.Parent <> ttMaster.Variant
	|			AND ReportsVariants.Ref <> ttMaster.Variant
	|WHERE
	|	(ReportsVariants.User
	|			OR Not ReportsVariants.DeletionMark)";
	
	Query = New Query;
	Query.SetParameter("MainReportsVariants", Cache.MainVariants);
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VariantObject = Selection.Ref.GetObject();
		VariantObject.Parent = Selection.Parent;
		VariantObject.Lock();
		InfobaseUpdate.WriteData(VariantObject, VariantObject.IsNew(), False);
	EndDo;
	
	ProcedureCompletion(ProcedureRepresentation);
EndProcedure

// Updates predefined data in the separated mode.
Procedure UpdateSeparatedPredefined(Cache, Patterns, TableRow)
	If TableRow.Processed Then
		Return;
	EndIf;
	
	TableRow.Processed = True;
	
	If TableRow.SetDeletionMark Then // Mark for deletion.
		If PropertiesValuesMatch(Patterns.SettingMarkDeletion, TableRow, "Attribute") Then
			Return; // Already marked.
		EndIf;
		VariantObject = TableRow.AttributeRef.GetObject();
		FillPropertyValues(VariantObject, Patterns.SettingMarkDeletion);
	Else
		If TableRow.GroupByReport AND Not ValueIsFilled(TableRow.PredefinedVariantParent) Then
			TableRow.Parent = Cache.EmptyRef;
		EndIf;
		Cache.ProcessedPredefined.Add(TableRow.PredefinedVariant);
		FillPropertyValues(Patterns.UpdateInformation, TableRow);
		Patterns.UpdateInformation.DeletionMark = False;
		If TableRow.CreateNew Then // Add.
			VariantObject = Catalogs.ReportsVariants.CreateItem();
			VariantObject.PredefinedVariant = TableRow.PredefinedVariant;
			VariantObject.ReportType = Enums.ReportsTypes.Internal;
			VariantObject.User = False;
		Else // Update (if there are changes).
			If PropertiesValuesMatch(Patterns.UpdateInformation, TableRow, "Attribute") Then
				Return; // No changes.
			EndIf;
			// Transfer user settings.
			ReplaceKeysCustomizations(Patterns.UpdateInformation, TableRow);
			VariantObject = TableRow.AttributeRef.GetObject();
		EndIf;
		If VariantObject.VisibleByDefaultIsOverridden Then
			ExcludingProperties = "VisibleByDefault";
		Else
			ExcludingProperties = Undefined;
		EndIf;
		FillPropertyValues(VariantObject, Patterns.UpdateInformation, , ExcludingProperties);
	EndIf;
	
	VariantObject.Lock();
	InfobaseUpdate.WriteData(VariantObject, VariantObject.IsNew(), False);
	
	TableRow.AttributeRef = VariantObject.Ref;
EndProcedure

// Returns True if values of properties Structure and Collection with Prefix match.
Function PropertiesValuesMatch(Structure, Collection, PrefixInCollection = "")
	For Each KeyAndValue IN Structure Do
		If Collection[PrefixInCollection + KeyAndValue.Key] <> KeyAndValue.Value Then
			Return False;
		EndIf;
	EndDo;
	Return True;
EndFunction

// Set deletion mark of deleted reports variants.
Procedure MarkOnDeletionDeletedReportVariants(Cache, SharedData)
	Query = New Query;
	Query.Text =
	"SELECT
	|	CatalogData.Ref
	|FROM
	|	Catalog.PredefinedReportsVariants AS CatalogData
	|WHERE
	|	CatalogData.DeletionMark = FALSE
	|	AND (CatalogData.Report = UNDEFINED
	|			OR CatalogData.Report.DeletionMark = TRUE)";
	
	If Not SharedData Then
		Query.Text = StrReplace(Query.Text, "Catalog.PredefinedReportsVariants", "Catalog.ReportsVariants");
	EndIf;
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	If SharedData Then
		Cache.RefreshAreas = True;
		Suffix = NStr("en='common data';ru='общие данные'");
	Else
		Suffix = NStr("en='data area';ru='область данных'");
	EndIf;
	
	ProcedureRepresentation = NStr("en='Deletion of the deleted report variants';ru='Удаление вариантов удаленных отчетов'") + " (" + Suffix + ")";
	ProcedureLaunch(ProcedureRepresentation);
	
	OptionsRefsArray = Result.Unload().UnloadColumn("Ref");
	For Each VariantRef IN OptionsRefsArray Do
		VariantObject = VariantRef.GetObject();
		VariantObject.Lock();
		VariantObject.DeletionMark = True;
		WritePredefined(VariantObject);
	EndDo;
	
	ProcedureCompletion(ProcedureRepresentation);
EndProcedure

// Transfer variant user settings from the corresponding storage.
Procedure ReplaceKeysCustomizations(OldVariant, ActualVariant)
	If OldVariant.VariantKey = ActualVariant.VariantKey
		Or Not ValueIsFilled(OldVariant.VariantKey)
		Or Not ValueIsFilled(ActualVariant.VariantKey)
		Or TypeOf(ActualVariant.Report) <> Type("CatalogRef.MetadataObjectIDs") Then
		Return;
	EndIf;
	
	ReportFullName = ActualVariant.Report.DescriptionFull;
	OldObjectKey = ReportFullName +"/"+ OldVariant.VariantKey;
	NewObjectKey = ReportFullName +"/"+ ActualVariant.VariantKey;
	
	Filter = New Structure("ObjectKey", OldObjectKey);
	StorageSelection = ReportsUserSettingsStorage.Select(Filter);
	ReadErrorsInRow = 0;
	While True Do
		// Read settings from storage by an old key.
		Try
			ItemSampleIsObtained = StorageSelection.Next();
			ReadErrorsInRow = 0;
		Except
			ItemSampleIsObtained = Undefined;
			ReadErrorsInRow = ReadErrorsInRow + 1;
			ErrorByVariant(
				OldVariant.Ref,
				NStr("en='An error occurred while selecting reports variants from the standard storage';ru='В процессе выборки вариантов отчетов из стандартного хранилища возникла ошибка:'")
				+ Chars.LF
				+ DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		If ItemSampleIsObtained = False Then
			Break;
		ElsIf ItemSampleIsObtained = Undefined Then
			If ReadErrorsInRow > 100 Then
				Break;
			Else
				Continue;
			EndIf;
		EndIf;
		
		// Settings description reading.
		SettingsDescription = ReportsUserSettingsStorage.GetDescription(
			StorageSelection.ObjectKey,
			StorageSelection.SettingsKey,
			StorageSelection.User);
		
		// Write settings to storage by a new key.
		ReportsUserSettingsStorage.Save(
			NewObjectKey,
			StorageSelection.SettingsKey,
			StorageSelection.Settings,
			SettingsDescription,
			StorageSelection.User);
	EndDo;
	
	// Clear storage old settings.
	ReportsUserSettingsStorage.Delete(OldObjectKey, Undefined, Undefined);
EndProcedure

// Writes a predetermined object.
Procedure WritePredefined(VariantObject)
	VariantObject.AdditionalProperties.Insert("PredefinedOnesFilling");
	InfobaseUpdate.WriteData(VariantObject, VariantObject.IsNew(), False);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update / Transition to edition 2.1.

// Settings storage structure replacement by sections, transition to references of MOI catalog.
//   Called only for internal reports variants.
//
Procedure Edition21BringSettingsBySections(VariantObject)
	
	Found = VariantObject.Placement.FindRows(New Structure("Subsystem", Catalogs.MetadataObjectIDs.EmptyRef()));
	For Each TableRow IN Found Do
		
		If Not ValueIsFilled(TableRow.DeleteSubsystem) Then
			VariantObject.Placement.Delete(TableRow);
			Continue;
		EndIf;
		
		SubsystemFullName = "Subsystem." + StrReplace(TableRow.DeleteSubsystem, "\", ".Subsystem.");
		SubsystemMetadata = Metadata.FindByFullName(SubsystemFullName);
		If SubsystemMetadata = Undefined Then
			VariantObject.Placement.Delete(TableRow);
			Continue;
		EndIf;
		
		SubsystemRef = CommonUse.MetadataObjectID(SubsystemMetadata);;
		If Not ValueIsFilled(SubsystemRef) Then
			VariantObject.Placement.Delete(TableRow);
			Continue;
		EndIf;
		
		TableRow.Use = True;
		TableRow.Subsystem = SubsystemRef;
		TableRow.DeleteSubsystem = "";
		TableRow.DeleteName = "";
		
	EndDo;
	
EndProcedure

// Fill in the "ReportsVariantsSettings" register.
//   Called only for internal reports variants.
//
Procedure Edition21TransferUserSettingsToRegister(VariantObject)
	SubsystemTable = VariantObject.Placement.Unload(New Structure("Use", True));
	SubsystemTable.GroupBy("Subsystem");
	
	UsersTable = VariantObject.DeleteQuickAccessExceptions.Unload();
	UsersTable.Columns.DeleteUser.Name = "User";
	UsersTable.GroupBy("User");
	
	SettingsPackage = New ValueTable;
	SettingsPackage.Columns.Add("Subsystem",   SubsystemTable.Columns.Subsystem.Type);
	SettingsPackage.Columns.Add("User", UsersTable.Columns.User.Type);
	SettingsPackage.Columns.Add("Visible",    New TypeDescription("Boolean"));
	
	For Each RowSubsystem IN SubsystemTable Do
		For Each UserRow IN UsersTable Do
			Setting = SettingsPackage.Add();
			Setting.Subsystem   = RowSubsystem.SectionOrGroup;
			Setting.User = UserRow.User;
			Setting.Visible    = Not VariantObject.VisibleByDefault;
		EndDo;
	EndDo;
	
	Dimensions = New Structure("Variant", VariantObject.Ref);
	Resources   = New Structure("QuickAccess", False);
	InformationRegisters.ReportsVariantsSettings.WriteSettingsPackage(SettingsPackage, Dimensions, Resources, True);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with subsystems tree from forms.

// Adds conditional design items of the subsystems tree.
Procedure SubsystemsTreeAddConditionalAppearance(Form) Export
	Form.Items.SubsystemsTreeImportance.ChoiceList.Add(ReportsVariantsClientServer.PresentationImportant());
	Form.Items.SubsystemsTreeImportance.ChoiceList.Add(ReportsVariantsClientServer.PresentationSeeAlso());
	
	Instruction = ConditionalDesignInstruction();
	Instruction.Fields = "SubsystemsTree";
	Instruction.Filters.Insert("SubsystemsTree.Priority", "");
	Instruction.Appearance.Insert("ReadOnly", True);
	AddConditionalAppearanceItem(Form, Instruction);
	
	Instruction = ConditionalDesignInstruction();
	Instruction.Fields = "SubsystemsTreeUsage, SubsystemsTreeImportance";
	Instruction.Filters.Insert("SubsystemsTree.Priority", "");
	Instruction.Appearance.Insert("Show", False);
	AddConditionalAppearanceItem(Form, Instruction);
EndProcedure

// Description of the instruction to add items of conditional design.
Function ConditionalDesignInstruction() Export
	Return New Structure("Filters, Appearance, Fields", New Map, New Map, "");
EndFunction

// Adds an item of conditional design according to description in the instruction.
Function AddConditionalAppearanceItem(Form, ConditionalDesignInstruction) Export
	DCConditionalAppearanceItem = Form.ConditionalAppearance.Items.Add();
	DCConditionalAppearanceItem.Use = True;
	
	For Each KeyAndValue IN ConditionalDesignInstruction.Filters Do
		DCFilterItem = DCConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		DCFilterItem.LeftValue = New DataCompositionField(KeyAndValue.Key);
		Setting = KeyAndValue.Value;
		Type = TypeOf(Setting);
		If Type = Type("Structure") Then
			DCFilterItem.ComparisonType = DataCompositionComparisonType[Setting.Type];
			DCFilterItem.RightValue = Setting.Value;
		ElsIf Type = Type("Array") Then
			DCFilterItem.ComparisonType = DataCompositionComparisonType.InList;
			DCFilterItem.RightValue = Setting;
		ElsIf Type = Type("DataCompositionComparisonType") Then
			DCFilterItem.ComparisonType = Setting;
		Else
			DCFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			DCFilterItem.RightValue = Setting;
		EndIf;
		DCFilterItem.Application = DataCompositionFilterApplicationType.Items;
	EndDo;
	
	For Each KeyAndValue IN ConditionalDesignInstruction.Appearance Do
		DCConditionalAppearanceItem.Appearance.SetParameterValue(
			New DataCompositionParameter(KeyAndValue.Key),
			KeyAndValue.Value);
	EndDo;
	
	Fields = ConditionalDesignInstruction.Fields;
	If TypeOf(Fields) = Type("String") Then
		Fields = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Fields, ",", True, True);
	EndIf;
	For Each Field IN Fields Do
		DCField = DCConditionalAppearanceItem.Fields.Items.Add();
		DCField.Use = True;
		DCField.Field = New DataCompositionField(Field);
	EndDo;
	
	Return DCConditionalAppearanceItem;
EndFunction

// Generates subsystems tree by the variant base data.
Function SubsystemsTreeGenerate(Form, OptionBasis) Export
	// Empty tree without settings.
	Prototype = Form.FormAttributeToValue("SubsystemsTree", Type("ValueTree"));
	SubsystemsTree = ReportsVariantsReUse.CurrentUserSubsystems().Copy();
	For Each PrototypeColumn IN Prototype.Columns Do
		If SubsystemsTree.Columns.Find(PrototypeColumn.Name) = Undefined Then
			SubsystemsTree.Columns.Add(PrototypeColumn.Name, PrototypeColumn.ValueType);
		EndIf;
	EndDo;
	
	// Parameters.
	Context = New Structure("SubsystemsTree");
	Context.SubsystemsTree = SubsystemsTree;
	
	// Placement set by an administrator.
	Subsystems = New Array;
	For Each RowOfPlacement IN OptionBasis.Placement Do
		Subsystems.Add(RowOfPlacement.Subsystem);
		SubsystemsTreeRegisterSubsystemSettings(Context, RowOfPlacement, RowOfPlacement.Use);
	EndDo;
	
	// Placement predefined by a developer.
	Query = New Query("SELECT * FROM Catalog.PredefinedReportsVariants.Placement WHERE Ref = &Ref AND Not Subsystem IN (&Subsystems)");
	Query.SetParameter("Ref", OptionBasis.PredefinedVariant);
	// Do not read subsystems settings predefined by administrator.
	Query.SetParameter("Subsystems", Subsystems);
	AccommodationOfPredefined = Query.Execute().Unload();
	For Each RowOfPlacement IN AccommodationOfPredefined Do
		SubsystemsTreeRegisterSubsystemSettings(Context, RowOfPlacement, True);
	EndDo;
	
	Return Context.SubsystemsTree;
EndFunction

// Adds subsystem to the tree.
Procedure SubsystemsTreeRegisterSubsystemSettings(Context, RowOfPlacement, Use)
	Found = Context.SubsystemsTree.Rows.FindRows(New Structure("Ref", RowOfPlacement.Subsystem), True);
	If Found.Count() = 0 Then
		Return;
	EndIf;
	
	TreeRow = Found[0];
	
	If RowOfPlacement.Important Then
		TreeRow.Importance = ReportsVariantsClientServer.PresentationImportant();
	ElsIf RowOfPlacement.SeeAlso Then
		TreeRow.Importance = ReportsVariantsClientServer.PresentationSeeAlso();
	Else
		TreeRow.Importance = "";
	EndIf;
	TreeRow.Use = Use;
EndProcedure

// Saves the placing settings changed by a user to a tabular section of report variant.
//
// Parameters:
//   Form         - ManagedForm - Form where placement settings are stored.
//   VariantObject - CatalogObject.ReportsVariants, FormDataStructure - Report variant object.
//   Cache           - Structure - Optional.
//
Procedure SubsystemsTreeWrite(Form, VariantObject, Cache = Undefined) Export
	If Cache = Undefined Then
		Cache = New Structure;
	EndIf;
	If Cache.Property("SubsystemsChanges") Then
		SubsystemsChanges = Cache.SubsystemsChanges;
	Else
		TreeReceiver = Form.FormAttributeToValue("SubsystemsTree", Type("ValueTree"));
		If VariantObject.IsNew() Then
			SubsystemsChanges = TreeReceiver.Rows.FindRows(New Structure("Use", 1), True);
		Else
			SubsystemsChanges = TreeReceiver.Rows.FindRows(New Structure("Modified", True), True);
		EndIf;
		Cache.Insert("SubsystemsChanges", SubsystemsChanges);
	EndIf;
	
	For Each Subsystem IN SubsystemsChanges Do
		TabularSectionRow = VariantObject.Placement.Find(Subsystem.Ref, "Subsystem");
		If TabularSectionRow = Undefined Then
			// It is required to unconditionally register variant placement setting (even the Usage disabled check box)
			// - only when this setting will replace the predefined one (from undivided catalog).
			TabularSectionRow = VariantObject.Placement.Add();
			TabularSectionRow.Subsystem = Subsystem.Ref;
		EndIf;
		
		If Subsystem.Use = 0 Then
			TabularSectionRow.Use = False;
		ElsIf Subsystem.Use = 1 Then
			TabularSectionRow.Use = True;
		Else
			// Leave as it is.
		EndIf;
		
		If Subsystem.Importance = ReportsVariantsClientServer.PresentationImportant() Then
			TabularSectionRow.Important  = True;
			TabularSectionRow.SeeAlso = False;
		ElsIf Subsystem.Importance = ReportsVariantsClientServer.PresentationSeeAlso() Then
			TabularSectionRow.Important  = False;
			TabularSectionRow.SeeAlso = True;
		Else
			TabularSectionRow.Important  = False;
			TabularSectionRow.SeeAlso = False;
		EndIf;
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Generate presentations of fields, parameters and filters for search.

// Called from the OnWrite variants event. Some checks are executed before the call.
Function IndexSchemaContent(VariantObject) Export
	Var IndexSchema, ReportObject, DCSettings, IsPredefined;
	
	AdditionalProperties = VariantObject.AdditionalProperties;
	
	// IN some cases it is known beforehand that the settings are already indexed.
	AdditionalProperties.Property("IndexSchema", IndexSchema);
	If IndexSchema = False Then
		Return False; // Filling out is not required.
	EndIf;
	CheckHash = True;
	If IndexSchema = True Then
		CheckHash = False;
	EndIf;
	
	// Mechanics of manual indexing from variant data.
	IndexDescriptionFields = Left(VariantObject.FieldNames, 1) <> "#";
	IndexParametersAndFiltersNames = Left(VariantObject.ParametersAndFiltersNames, 1) <> "#";
	If Not IndexDescriptionFields AND Not IndexParametersAndFiltersNames Then
		Return False; // Filling out is not required.
	EndIf;
	
	// Receive report object, DLS settings and variant.
	IsPredefined = False;
	
	// Settings of the predefined ones are from values tree that is passed in the additional parameters.
	If TypeOf(VariantObject) = Type("CatalogObject.PredefinedReportsVariants") Then
		IsPredefined = True;
		
		Search = New Structure("Report, VariantKey, IsOption", VariantObject.Report, VariantObject.VariantKey, True);
		Found = AdditionalProperties.OptionsTree.Rows.FindRows(Search, True);
		If Found.Count() = 0 Then
			ErrorText = NStr("en='Variant ""%1"" is not found for report ""%2""';ru='Вариант ""%1"" не найден для отчета ""%2""'");
			ErrorByVariant(VariantObject.Ref, ErrorText, VariantObject.VariantKey, VariantObject.Report);
			Return False; // Problem detected.
		EndIf;
		
		VariantDesc = Found[0];
		RowReport = VariantDesc.Parent;
		FillDetailsRowsOption(VariantDesc, RowReport);
		
		// If variant is disabled, then it does not take part in the search.
		If Not VariantDesc.Enabled Then
			Return False; // Filling out is not required.
		EndIf;
		
		// Preset search settings.
		If ValueIsFilled(VariantDesc.SearchSettings.FieldNames) Then
			VariantObject.FieldNames = "#" + TrimAll(VariantDesc.SearchSettings.FieldNames);
			IndexDescriptionFields = False;
		EndIf;
		If ValueIsFilled(VariantDesc.SearchSettings.ParametersAndFiltersNames) Then
			VariantObject.ParametersAndFiltersNames = "#" + TrimAll(VariantDesc.SearchSettings.ParametersAndFiltersNames);
			IndexParametersAndFiltersNames = False;
		EndIf;
		If Not IndexDescriptionFields AND Not IndexParametersAndFiltersNames Then
			Return True; // Filled out - the object must be written.
		EndIf;
		
		// Report object.
		If Not RowReport.SystemInfo.BuiltOnDCS Then
			If RowReport.Placement.Count() > 0 Then
				ErrorText = NStr("en='For report ""%2"" search settings are not filled in: names of fields or parameters and filters.
		|For more information - see the ""SetReportVariants"" procedure of the ""ReportVariantsPredefined"" module.';ru='Для отчета ""%2"" не заполнены настройки поиска: наименования полей или параметров и отборов.
		|Подробнее - см. процедуру ""НастроитьВариантыОтчетов"" модуля ""ВариантыОтчетовПереопределяемый"".'");
				ErrorByVariant(VariantObject.Ref, ErrorText, "", VariantObject.Report);
			EndIf;
			Return False; // Problem detected.
		EndIf;
		If Not RowReport.SystemInfo.Property("ReportObject") Then
			Return False; // A problem occurred (already written in the ObjectsVariantssettingsTree function).
		EndIf;
		ReportObject = RowReport.SystemInfo.ReportObject;
		
		// You can extract layout texts only after you receive report object.
		If IndexDescriptionFields AND ValueIsFilled(VariantDesc.SearchSettings.TemplateNames) Then
			VariantObject.FieldNames = "#" + ExtractLayoutText(ReportObject, VariantDesc.SearchSettings.TemplateNames);
			IndexDescriptionFields = False;
		EndIf;
		If Not IndexDescriptionFields AND Not IndexParametersAndFiltersNames Then
			Return True; // Filled out - the object must be written.
		EndIf;
		
		// Data layout settings.
		If Not VariantDesc.SystemInfo.Property("DCSettings") Then
			Return False; // A problem occurred (already written in the ObjectsVariantssettingsTree function).
		EndIf;
		DCSettings = VariantDesc.SystemInfo.DCSettings;
	Else
		If Not VariantObject.User Then
			IsPredefined = True;
		EndIf;
	EndIf;
	
	// IN some scripts, the object can be cached in additional properties.
	If ReportObject = Undefined Then
		AdditionalProperties.Property("ReportObject", ReportObject);
	EndIf;
	
	// When report object is not cashed. - connect the report using a standard method.
	If ReportObject = Undefined Then
		ConnectionResult = ConnectReportObject(VariantObject.Report);
		If Not ConnectionResult.Connected Then // The report is not found.
			ErrorByVariant(VariantObject.Ref, ConnectionResult.Errors);
			Return False; // Problem detected.
		EndIf;
		ReportObject = ConnectionResult.Object;
	EndIf;
	
	// Layout schema based on which report will be generated.
	DCSchema = ReportObject.DataCompositionSchema;
	
	// If report is not on DLS, therefore, presentations are not filled in or filled in with the applied mechanism.
	If DCSchema = Undefined Then
		If Not ValueIsFilled(VariantObject.FieldNames)
			Or Not ValueIsFilled(VariantObject.ParametersAndFiltersNames) Then
			ErrorText = NStr("en='For variant ""%1"" of report ""%2"" the search settings are not specified: field names or parameters and filters.';ru='Для варианта ""%1"" отчета ""%2"" не заполнены настройки поиска: наименования полей или параметров и отборов.'");
			InformationByOption(VariantObject.Ref, ErrorText, VariantObject.VariantKey, VariantObject.Report);
		EndIf;
		Return False; // Problem detected.
	EndIf;
	
	// Read settings from the passed parameters.
	If TypeOf(DCSettings) <> Type("DataCompositionSettings") Then
		AdditionalProperties.Property("DCSettings", DCSettings);
	EndIf;
	
	// Read settings from schema.
	If TypeOf(DCSettings) <> Type("DataCompositionSettings") Then
		DCSettingsVariant = DCSchema.SettingVariants.Find(VariantObject.VariantKey);
		If DCSettingsVariant <> Undefined Then
			DCSettings = DCSettingsVariant.Settings;
		EndIf;
	EndIf;
	
	// Read settings from variant data.
	If TypeOf(DCSettings) <> Type("DataCompositionSettings") Then
		DCSettings = VariantObject.Settings.Get();
	EndIf;
	
	// Last check.
	If TypeOf(DCSettings) <> Type("DataCompositionSettings") Then
		Return False; // Problem detected.
	EndIf;
	
	DataHashing = New DataHashing(HashFunction.MD5);
	DataHashing.Append(CommonUse.ValueToXMLString(DCSettings));
	TheseSettingsHash = StrReplace(DataHashing.HashSum, " ", "");
	If CheckHash AND VariantObject.SettingsHash = TheseSettingsHash Then
		Return False; // Settings have not changed.
	EndIf;
	VariantObject.SettingsHash = TheseSettingsHash;
	
	// Describes the connection of data layout settings and data layout schema.
	DCSettingsComposer = ReportObject.SettingsComposer;
	
	// Initializes linker and its settings (Settings) with the available settings source.
	DCSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DCSchema));
	
	// Imports settings to linker.
	DCSettingsComposer.LoadSettings(DCSettings);
	
	If IndexDescriptionFields Then
		// Convert all settings of auto grouping to fields set.See
		//   "AutoSelectedDataLayoutField"
		//   "DataLayoutAutoField" "DataLayoutOrderAutoItem" in syntax assistant.
		DCSettingsComposer.ExpandAutoFields();
		
		VariantObject.FieldNames = GenerateFieldsPresentation(DCSettingsComposer);
	EndIf;
	
	If IndexParametersAndFiltersNames Then
		VariantObject.ParametersAndFiltersNames = GenerateParametersAndFiltersPresentations(DCSettingsComposer);
	EndIf;
	
	Return True;
EndFunction

// Presentations of groupings and fields from DLS.
Function GenerateFieldsPresentation(DCSettingsComposer) Export
	Result = New Array;
	
	ExpandArrayFromRowWithSeparators(Result, String(DCSettingsComposer.Settings.Selection));
	
	CollectionsArray = New Array;
	CollectionsArray.Add(DCSettingsComposer.Settings.Structure);
	While CollectionsArray.Count() > 0 Do
		Collection = CollectionsArray[0];
		CollectionsArray.Delete(0);
		
		For Each Setting IN Collection Do
			
			If TypeOf(Setting) = Type("DataCompositionNestedObjectSettings") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				Setting = Setting.Settings;
			EndIf;
			
			ExpandArrayFromRowWithSeparators(Result, String(Setting.Selection));
			
			If TypeOf(Setting) = Type("DataCompositionSettings") Then
				CollectionsArray.Add(Setting.Structure);
			ElsIf TypeOf(Setting) = Type("DataCompositionGroup") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				CollectionsArray.Add(Setting.Structure);
			ElsIf TypeOf(Setting) = Type("DataCompositionTable") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				CollectionsArray.Add(Setting.Rows);
			ElsIf TypeOf(Setting) = Type("DataCompositionTableGroup") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				CollectionsArray.Add(Setting.Structure);
			ElsIf TypeOf(Setting) = Type("DataCompositionChart") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				CollectionsArray.Add(Setting.Series);
				CollectionsArray.Add(Setting.Points);
			ElsIf TypeOf(Setting) = Type("DataCompositionChartGroup") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				CollectionsArray.Add(Setting.Structure);
			EndIf;
			
		EndDo;
		
	EndDo;
	
	StorageDelimiter = ReportsVariantsClientServer.StorageDelimiter();
	Return StringFunctionsClientServer.RowFromArraySubrows(Result, StorageDelimiter);
EndFunction

// Presentations of parameters and filters from DLS.
Function GenerateParametersAndFiltersPresentations(DCSettingsComposer) Export
	Result = New Array;
	
	DCSettings = DCSettingsComposer.Settings;
	
	Modes = DataCompositionSettingsItemViewMode;
	
	For Each UserSetting IN DCSettingsComposer.UserSettings.Items Do
		SettingType = TypeOf(UserSetting);
		If SettingType = Type("DataCompositionSettingsParameterValue") Then
			ItIsSelection = False;
		ElsIf SettingType = Type("DataCompositionFilterItem") Then
			ItIsSelection = True;
		Else
			Continue;
		EndIf;
		
		If UserSetting.ViewMode = Modes.Inaccessible Then
			Continue;
		EndIf;
		
		ID = UserSetting.UserSettingID;
		
		CommonSetting = ReportsClientServer.GetObjectByUserIdentifier(DCSettings, ID);
		If CommonSetting = Undefined Then
			Continue;
		ElsIf UserSetting.ViewMode = Modes.Auto
			AND CommonSetting.ViewMode <> Modes.QuickAccess Then
			Continue;
		EndIf;
		
		PresentationsStructure = New Structure("Presentation, UserSettingPresentation", "", "");
		FillPropertyValues(PresentationsStructure, CommonSetting);
		If ValueIsFilled(PresentationsStructure.UserSettingPresentation) Then
			ItemHeader = PresentationsStructure.UserSettingPresentation;
		ElsIf ValueIsFilled(PresentationsStructure.Presentation) Then
			ItemHeader = PresentationsStructure.Presentation;
		Else
			AvailableSetting = ReportsClientServer.FindAvailableSetting(DCSettings, CommonSetting);
			If AvailableSetting <> Undefined AND ValueIsFilled(AvailableSetting.Title) Then
				ItemHeader = AvailableSetting.Title;
			Else
				ItemHeader = String(?(ItIsSelection, CommonSetting.LeftValue, CommonSetting.Parameter));
			EndIf;
		EndIf;
		
		ItemHeader = TrimAll(ItemHeader);
		If ItemHeader <> "" AND Result.Find(ItemHeader) = Undefined Then
			Result.Add(ItemHeader);
		EndIf;
		
	EndDo;
	
	StorageDelimiter = ReportsVariantsClientServer.StorageDelimiter();
	Return StringFunctionsClientServer.RowFromArraySubrows(Result, StorageDelimiter);
EndFunction

// Extracts text information from the layout.
Function ExtractLayoutText(ReportObject, TemplateNames) Export
	ExtractedText = "";
	If TypeOf(TemplateNames) = Type("String") Then
		TemplateNames = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(
			TemplateNames,
			",",
			True,
			True);
	EndIf;
	For Each TemplateName IN TemplateNames Do
		Template = ReportObject.GetTemplate(TemplateName);
		If TypeOf(Template) = Type("SpreadsheetDocument") Then
			Bottom = Template.TableHeight;
			Right = Template.TableWidth;
			CheckedCells = New Map;
			For ColumnNumber = 1 To Right Do
				For LineNumber = 1 To Bottom Do
					Cell = Template.Area(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
					If CheckedCells.Get(Cell.Name) = Undefined Then
						CheckedCells.Insert(Cell.Name, True);
						If TypeOf(Cell) = Type("SpreadsheetDocumentRange") Then
							AreaText = TrimAll(Cell.Text);
							If AreaText <> "" Then
								ExtractedText = ExtractedText + Chars.LF + AreaText;
							EndIf;
						EndIf;
					EndIf;
				EndDo;
			EndDo;
		ElsIf TypeOf(Template) = Type("TextDocument") Then
			ExtractedText = ExtractedText + Chars.LF + TrimAll(Template.GetText());
		EndIf;
	EndDo;
	ExtractedText = TrimL(ExtractedText);
	Return ExtractedText;
EndFunction

// Adds to Array items from RowWithSeparators if there are no items.
Procedure ExpandArrayFromRowWithSeparators(Array, StringWithSeparators)
	StringWithSeparators = TrimAll(StringWithSeparators);
	If StringWithSeparators = "" Then
		Return;
	EndIf;
	Position = Find(StringWithSeparators, ",");
	While Position > 0 Do
		Substring = TrimR(Left(StringWithSeparators, Position - 1));
		If Substring <> "" AND Array.Find(Substring) = Undefined Then
			Array.Add(Substring);
		EndIf;
		StringWithSeparators = TrimL(Mid(StringWithSeparators, Position + 1));
		Position = Find(StringWithSeparators, ",");
	EndDo;
	If StringWithSeparators <> "" AND Array.Find(StringWithSeparators) = Undefined Then
		Array.Add(StringWithSeparators);
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Reduce user settings quantity.

// Called from the OnWrite variants event. Some checks are executed before the call.
Function DecreaseQuickSettingsQuantity(VariantObject, ReportObject) Export
	Var DCSettings, IsPredefined;
	
	If VariantObject = Undefined Then
		Return False; // The variant does not exist in the base. Filling out is not required.
	EndIf;
	
	// Layout schema based on which report will be generated.
	DCSchema = ReportObject.DataCompositionSchema;
	If DCSchema = Undefined Then
		Return False; // Report not on DCS. Filling out is not required.
	EndIf;
	
	// Read settings from variant data.
	DCSettings = VariantObject.Settings.Get();
	If TypeOf(DCSettings) <> Type("DataCompositionSettings") Then
		ErrorText = NStr("en='Empty settings of the user variant ""%1"" of the report are found ""%2"".';ru='Обнаружены пустые настройки пользовательского варианта ""%1"" отчета ""%2"".'");
		ErrorByVariant(VariantObject.Ref, ErrorText, VariantObject.VariantKey, VariantObject.Report);
		Return False; // Problem detected.
	EndIf;
	
	// Describes the connection of data layout settings and data layout schema.
	DCSettingsComposer = ReportObject.SettingsComposer;
	
	// Initializes linker and its settings (Settings) with the available settings source.
	DCSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DCSchema));
	
	// Imports settings to linker.
	DCSettingsComposer.LoadSettings(DCSettings);
	
	OutputConditions = New Structure;
	OutputConditions.Insert("OnlyCustom", True);
	OutputConditions.Insert("OnlyQuick",          True);
	OutputConditions.Insert("CurrentCDHostIdentifier", Undefined);
	Information = ReportsServer.ExtendedInformationAboutSettings(DCSettingsComposer, Undefined, OutputConditions);
	QuickSettings = Information.UserSettings.Copy(New Structure("OutputAllowed, Quick", True, True));
	If QuickSettings.Count() <= 2 Then
		Return False; // Reducing the number is not required.
	EndIf;
	
	Excluded = QuickSettings.FindRows(New Structure("ItemsType", "StandardPeriod"));
	For Each TableRow IN Excluded Do
		QuickSettings.Delete(TableRow);
	EndDo;
	
	Spent = Excluded.Count();
	For Each TableRow IN QuickSettings Do
		If Spent < 2 Then
			Spent = Spent + 1;
			Continue;
		EndIf;
		TableRow.KDVariantSetting.ViewMode = DataCompositionSettingsItemViewMode.Normal;
	EndDo;
	
	VariantObject.Settings = New ValueStorage(DCSettingsComposer.Settings);
	
	Return True;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Search.

// If it is possible to index report schema content.
Function UndividedDataIndexationAllowed() Export
	Return Not CommonUseReUse.DataSeparationEnabled();
EndFunction

// Finds references by search parameters.
//   Highlights found places.
//
// Parameters:
//   SearchParameters - Structure - Search conditions.
//       * SearchString - String - Optional.
//       * Author - CatalogRef.Users - Optional.
//       * Subsystems - Array From CatalogRef.MetadataObjectIDs - Optional.
//
// Returns: 
//   Structure - When search by string is executed.
//       * Refs - Array from CatalogRef.ReportsVariants -
//           Filled in with reports variants in which data all desired words are found.
//       * HighlightOptions - Map - Highlight the found words (if SearchString is specified).
//           ** Key - CatalogRef.ReportsVariants.
//           ** Value - Structure.
//               *** Ref - CatalogRef.ReportsVariants.
//               *** FieldNames                    - String.
//               *** ParametersAndFiltersNames       - String.
//               *** Definition                             - String.
//               *** UserSettingsNames - String.
//               *** WhereFound                           - Structure.
//                   **** FieldNames                    - Number.
//                   **** ParametersAndFiltersNames       - Number.
//                   **** Definition                             - Number.
//                   **** UserSettingsNames - Number.
//       * Subsystems - Array From CatalogRef.MetadataObjectIDs - 
//           Filled in by the subsystems in names of which all desired words are found.
//           All inserted reports variants should be output for such subsystems.
//       * SubsystemsHighlight - Map - Highlight the found words (if SearchString is specified).
//           ** Key - CatalogRef.ReportsVariants.
//           ** Value - Structure.
//               *** Ref - CatalogRef.MetadataObjectIDs.
//               *** SubsystemDescription - String.
//               *** AllWordsFound - Boolean.
//               *** FoundWords - Array.
//       * VariantsConnectedToSubsystems - Map - Reports variants and their subsystems.
//           Filled in when some words are found in variant data and the rest of them - in the names of its subsystems.
//           IN this case, the variant should be displayed only in found subsystems (and in other - should not be shown).
//           Used in reports panel.
//           ** Key - CatalogRef.ReportsVariants - Variant.
//           ** Value - Array From CatalogRef.MetadataObjectIDs - Subsystems.
//
Function FindReferences(SearchParameters) Export
	SearchParameters.Insert("UserReporting", CurrentUserReports());
	SearchParameters.Insert("DisabledApplicationOptions", ReportsVariantsReUse.DisabledApplicationOptions());
	
	If SearchParameters.Property("SearchString") AND ValueIsFilled(SearchParameters.SearchString) Then
		HasSearchString = True;
	Else
		HasSearchString = False;
	EndIf;
	
	If SearchParameters.Property("Reports") AND ValueIsFilled(SearchParameters.Reports) Then
		FilterByReportsExists = True;
	Else
		FilterByReportsExists = False;
	EndIf;
	
	If SearchParameters.Property("Subsystems") AND ValueIsFilled(SearchParameters.Subsystems) Then
		FilterBySubsystemsExist = True;
	Else
		FilterBySubsystemsExist = False;
	EndIf;
	
	If SearchParameters.Property("ReportsTypes") AND ValueIsFilled(SearchParameters.ReportsTypes) Then
		FilterByReportsTypesExist = True;
	Else
		FilterByReportsTypesExist = False;
	EndIf;
	
	If SearchParameters.Property("OnlyVisibleInReportPanel") AND SearchParameters.OnlyVisibleInReportPanel = True Then
		HasFilterByVisible = FilterBySubsystemsExist; // Supported only when filter by subsystems is specified.
	Else
		HasFilterByVisible = False;
	EndIf;
	
	If SearchParameters.Property("ReceiveSummaryTable") AND SearchParameters.ReceiveSummaryTable = True Then
		ReceiveSummaryTable = True;
	Else
		ReceiveSummaryTable = False;
	EndIf;
	
	If SearchParameters.Property("DeletionMark") Then
		HasFilterByDeletionMark = True;
	Else
		HasFilterByDeletionMark = False;
	EndIf;
	
	If Not FilterBySubsystemsExist AND Not HasSearchString AND Not FilterByReportsTypesExist AND Not FilterByReportsExists Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	
	CurrentUser = Users.AuthorizedUser();
	
	If FilterByReportsExists Then
		FilterByReports = New Array;
		For Each ReportRef IN SearchParameters.Reports Do
			If SearchParameters.UserReporting.Find(ReportRef) <> Undefined Then
				FilterByReports.Add(ReportRef);
			EndIf;
		EndDo;
	Else
		FilterByReports = SearchParameters.UserReporting;
	EndIf;
	
	Query.SetParameter("CurrentUser",          CurrentUser);
	Query.SetParameter("UserReporting",           FilterByReports);
	Query.SetParameter("DisabledApplicationOptions", SearchParameters.DisabledApplicationOptions);
	
	If FilterBySubsystemsExist Or HasSearchString Then
		QueryText =
		"SELECT ALLOWED
		|	ReportsVariants.Ref,
		|	ReportsVariants.Parent AS Parent,
		|	ReportsVariants.Description AS VariantName,
		|	ReportsVariants.Author AS Author,
		|	ReportsVariants.ForAuthorOnly AS ForAuthorOnly,
		|	CAST(ReportsVariants.Author.Description AS String(1000)) AS AuthorPresentation,
		|	ReportsVariants.Report AS Report,
		|	ReportsVariants.VariantKey AS VariantKey,
		|	ReportsVariants.ReportType AS ReportType,
		|	ReportsVariants.User AS User,
		|	ReportsVariants.PredefinedVariant AS PredefinedVariant,
		|	CASE
		|		WHEN SubString(ReportsVariants.ParametersAndFiltersNames, 1, 1) = """"
		|			THEN CAST(Predetermined.ParametersAndFiltersNames AS String(1000))
		|		ELSE CAST(ReportsVariants.ParametersAndFiltersNames AS String(1000))
		|	END AS ParametersAndFiltersNames,
		|	CASE
		|		WHEN SubString(ReportsVariants.FieldNames, 1, 1) = """"
		|			THEN CAST(Predetermined.FieldNames AS String(1000))
		|		ELSE CAST(ReportsVariants.FieldNames AS String(1000))
		|	END AS FieldNames,
		|	CASE
		|		WHEN SubString(ReportsVariants.Definition, 1, 1) = """"
		|			THEN CAST(Predetermined.Definition AS String(1000))
		|		ELSE CAST(ReportsVariants.Definition AS String(1000))
		|	END AS Definition,
		|	ReportsVariants.VisibleByDefault AS VisibleByDefault
		|INTO Variants
		|FROM
		|	Catalog.ReportsVariants AS ReportsVariants
		|		LEFT JOIN Catalog.PredefinedReportsVariants AS Predetermined
		|		ON ReportsVariants.PredefinedVariant = Predetermined.Ref
		|WHERE
		|	ReportsVariants.ReportType IN(&ReportsTypes)
		|	AND ReportsVariants.Report IN(&UserReporting)
		|	AND Not ReportsVariants.PredefinedVariant IN (&DisabledApplicationOptions)
		|	AND ReportsVariants.DeletionMark = FALSE
		|	AND Not ISNULL(Predetermined.DeletionMark, FALSE)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ISNULL(VariantsPlacement.Ref, PredefinedLocation.Ref) AS Ref,
		|	ISNULL(VariantsPlacement.Subsystem, PredefinedLocation.Subsystem) AS Subsystem,
		|	ISNULL(VariantsPlacement.SubsystemDescription, PredefinedLocation.SubsystemDescription) AS SubsystemDescription,
		|	ISNULL(VariantsPlacement.Use, TRUE) AS Use,
		|	CASE
		|		WHEN VariantsPlacement.Ref IS NULL 
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS DeveloperSetting
		|INTO PlaceAll
		|FROM
		|	(SELECT
		|		ReportsVariants.Ref AS Ref,
		|		LocationVariants.Use AS Use,
		|		LocationVariants.Subsystem AS Subsystem,
		|		LocationVariants.Subsystem.Synonym AS SubsystemDescription
		|	FROM
		|		Variants AS ReportsVariants
		|			INNER JOIN Catalog.ReportsVariants.Placement AS LocationVariants
		|			ON ReportsVariants.Ref = LocationVariants.Ref
		|				AND (LocationVariants.Subsystem IN (&SubsystemArray))) AS VariantsPlacement
		|		Full JOIN (SELECT
		|			ReportsVariants.Ref AS Ref,
		|			PredefinedLocation.Subsystem AS Subsystem,
		|			PredefinedLocation.Subsystem.Synonym AS SubsystemDescription
		|		FROM
		|			Variants AS ReportsVariants
		|				INNER JOIN Catalog.PredefinedReportsVariants.Placement AS PredefinedLocation
		|				ON (ReportsVariants.User = FALSE)
		|					AND ReportsVariants.PredefinedVariant = PredefinedLocation.Ref
		|					AND (PredefinedLocation.Subsystem IN (&SubsystemArray))) AS PredefinedLocation
		|		ON VariantsPlacement.Ref = PredefinedLocation.Ref
		|			AND VariantsPlacement.Subsystem = PredefinedLocation.Subsystem
		|WHERE
		|	ISNULL(VariantsPlacement.Use, TRUE)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	PlaceAll.Ref AS Ref,
		|	PlaceAll.Subsystem AS Subsystem,
		|	PlaceAll.SubsystemDescription AS SubsystemDescription
		|INTO PlaceVisible
		|FROM
		|	PlaceAll AS PlaceAll
		|		LEFT JOIN InformationRegister.ReportsVariantsSettings AS PersonalSettings
		|		ON PlaceAll.Subsystem = PersonalSettings.Subsystem
		|			AND PlaceAll.Ref = PersonalSettings.Variant
		|			AND (PersonalSettings.User = &CurrentUser)
		|		LEFT JOIN Variants AS Variants
		|		ON PlaceAll.Ref = Variants.Ref
		|WHERE
		|	ISNULL(PersonalSettings.Visible, Variants.VisibleByDefault)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ReportsVariants.Ref AS Ref,
		|	ReportsVariants.Parent AS Parent,
		|	ReportsVariants.VariantName AS VariantName,
		|	ReportsVariants.Author AS Author,
		|	ReportsVariants.AuthorPresentation AS AuthorPresentation,
		|	ReportsVariants.Report AS Report,
		|	ReportsVariants.Report.Name AS ReportName,
		|	ReportsVariants.VariantKey AS VariantKey,
		|	ReportsVariants.ReportType AS ReportType,
		|	ReportsVariants.User AS User,
		|	ReportsVariants.PredefinedVariant AS PredefinedVariant,
		|	ReportsVariants.ParametersAndFiltersNames AS ParametersAndFiltersNames,
		|	ReportsVariants.FieldNames AS FieldNames,
		|	ReportsVariants.Definition AS Definition,
		|	Placement.Subsystem AS Subsystem,
		|	Placement.SubsystemDescription AS SubsystemDescription,
		|	UNDEFINED AS UserSettingKey,
		|	UNDEFINED AS UserSettingPresentation
		|FROM
		|	Variants AS ReportsVariants
		|		INNER JOIN PlaceVisible AS Placement
		|		ON ReportsVariants.Ref = Placement.Ref
		|WHERE
		|	&VariantsAndSubsystemsSearch
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	Custom.Variant,
		|	Variants.Parent,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	UNDEFINED,
		|	Custom.UserSettingKey,
		|	Custom.Description
		|FROM
		|	Variants AS Variants
		|		INNER JOIN Catalog.UserReportsSettings AS custom
		|		ON Variants.Ref = Custom.Variant
		|WHERE
		|	Custom.User = &CurrentUser
		|	AND &UserSettingsSearch
		|	AND Custom.DeletionMark = FALSE";
		
		If HasFilterByVisible Then
			// The action is not required.
		Else
			// Delete the temporary table for filter by visible.
			DeleteTemporaryTable(QueryText, "PlaceVisible");
			// Name substitution of the temporary table from which selection should be executed.
			QueryText = StrReplace(QueryText, "PlaceVisible", "PlaceAll");
		EndIf;
		
		If FilterByReportsTypesExist Then
			Query.SetParameter("ReportsTypes", SearchParameters.ReportsTypes);
		Else
			// Delete filter by report type.
			QueryText = StrReplace(
				QueryText,
				"ReportsVariants.ReportType IN(&ReportsTypes)
		|	AND",
				"");
		EndIf;
		
		If FilterBySubsystemsExist Then
			If TypeOf(SearchParameters.Subsystems) = Type("Array") Then
				Query.SetParameter("SubsystemArray", SearchParameters.Subsystems);
			Else
				SubsystemArray = New Array;
				SubsystemArray.Add(SearchParameters.Subsystems);
				Query.SetParameter("SubsystemArray", SubsystemArray);
			EndIf;
		Else
			// Delete filter by subsystems.
			QueryText = StrReplace(QueryText, "AND (LocationVariants.Subsystem IN (&SubsystemArray))", "");
			QueryText = StrReplace(QueryText, "AND (PredefinedLocation.Subsystem IN (&SubsystemArray))", "");
		EndIf;
		
		If HasSearchString AND Not FilterBySubsystemsExist Then
			// To search, information about placing is additional, not key.
			If HasFilterByVisible Then
				QueryText = StrReplace(
					QueryText,
					"INNER JOIN VisiblePlacing AS Placement",
					"LEFT JOIN VisiblePlacement AS Placement");
			Else
				QueryText = StrReplace(
					QueryText,
					"INNER JOIN PlaceAll AS Placement",
					"LEFT JOIN PlaceAll AS Placement");
			EndIf;
		EndIf;
		
		If HasFilterByDeletionMark Then
			If SearchParameters.DeletionMark <> False Then
				QueryText = StrReplace(QueryText, ".DeletionMark = FALSE", ".DeletionMark = TRUE");
			EndIf;
		Else
			QueryText = StrReplace(QueryText, "AND ReportsVariants.DeletionMark = FALSE", "");
			QueryText = StrReplace(QueryText, "AND NOT ISNULL (Predefined.DeletionMark, FALSE)", "");
			QueryText = StrReplace(QueryText, "AND User.DeletionMark = FALSE", "");
		EndIf;
		
		If HasSearchString Then
			SearchString = Upper(TrimAll(SearchParameters.SearchString));
			SearchPattern = "";
			ArrayOfWords = ReportsVariantsClientServer.DecomposeSearchStringIntoWordsArray(SearchString);
			For WordNumber = 1 To ArrayOfWords.Count() Do
				Word = ArrayOfWords[WordNumber-1];
				NameWords = "Word" + Format(WordNumber, "NG=");
				Query.SetParameter(NameWords, "%" + Word + "%");
				Pattern = "<TableName.FieldName> LIKE &" + NameWords;
				If WordNumber = 1 Then
					SearchPattern = Pattern;
				Else
					SearchPattern = SearchPattern + Chars.LF + "				Or " + Pattern;
				EndIf;
			EndDo;
			
			// Condition for variants search.
			VariantsAndSubsystemsSearch = "("
				+ StrReplace(SearchPattern, "<TableName.FieldName>", "ReportsVariants.VariantName")
				+ "
				|				Or "
				+ StrReplace(SearchPattern, "<TableName.FieldName>", "Placement.SubsystemDescription")
				+ "
				|				Or "
				+ StrReplace(SearchPattern, "<TableName.FieldName>", "ReportsVariants.FieldNames")
				+ "
				|				Or "
				+ StrReplace(SearchPattern, "<TableName.FieldName>", "ReportsVariants.ParametersAndFiltersNames")
				+ "
				|				Or "
				+ StrReplace(SearchPattern, "<TableName.FieldName>", "ReportsVariants.Definition")
				+ "
				|				Or "
				+ StrReplace(SearchPattern, "<TableName.FieldName>", "ReportsVariants.AuthorPresentation")
				+ ")";
			QueryText = StrReplace(QueryText, "&VariantsAndSubsystemsSearch", VariantsAndSubsystemsSearch);
			
			UserSettingsSearch = (
				"("
				+ StrReplace(SearchPattern, "<TableName.FieldName>", "Custom.Description")
				+ ")"
			);
			QueryText = StrReplace(QueryText, "&UserSettingsSearch", UserSettingsSearch);
			
		Else
			// Delete selection for search in data of variants and subsystems.
			QueryText = StrReplace(
				QueryText,
				"WHERE
				|	&VariantsAndSubsystemsSearch",
				"");
			// Delete table for search among user settings.
			StartChoiceFromTable = (
				"UNION ALL
				|
				|SELECT DISTINCT
				|	Custom.Variant,");
			QueryText = TrimR(Left(QueryText, Find(QueryText, StartChoiceFromTable) - 1));
		EndIf;
		
		// Deleting unused fields when they are no longer used either for search or the result table.
		If Not HasSearchString AND Not ReceiveSummaryTable Then
			// VariantName
			QueryText = StrReplace(QueryText, "ReportsVariants.Name AS", "UNDEFINED AS");
			// FieldNames
			QueryText = StrReplace(
				QueryText,
				"CASE
				|		WHEN SubString(ReportsVariants.FieldNames, 1, 1) = """"
				|			THEN CAST(Predetermined.FieldNames AS String(1000))
				|		ELSE CAST(ReportsVariants.FieldNames AS String(1000))
				|	END AS",
				"UNDEFINED AS");
			// ParametersAndFiltersNames
			QueryText = StrReplace(
				QueryText,
				"CASE
				|		WHEN SubString(ReportsVariants.ParametersAndFiltersNames, 1, 1) = """"
				|			THEN CAST(Predetermined.ParametersAndFiltersNames AS String(1000))
				|		ELSE CAST(ReportsVariants.ParametersAndFiltersNames AS String(1000))
				|	END AS",
				"UNDEFINED AS");
			// Definition
			QueryText = StrReplace(
				QueryText,
				"CASE
				|		WHEN SubString(ReportsVariants.Definition, 1, 1) = """"
				|			THEN CAST(Predetermined.Definition AS String(1000))
				|		ELSE CAST(ReportsVariants.Definition AS String(1000))
				|	END AS",
				"UNDEFINED AS");
			// SubsystemDescription
			QueryText = StrReplace(
				QueryText,
				"VariantsPlacement.Subsystem.Synonym AS",
				"UNDEFINED AS");
			QueryText = StrReplace(
				QueryText,
				"PredefinedLocation.Subsystem.Synonym  AS",
				"UNDEFINED AS");
		EndIf;
		
		// Delete extra fields when they are not required for the final table.
		If Not ReceiveSummaryTable Then
			QueryText = StrReplace(QueryText, "ReportsVariants.Author AS", "UNDEFINED AS");
			QueryText = StrReplace(QueryText, "ReportsVariants.Report AS", "UNDEFINED AS");
			QueryText = StrReplace(QueryText, "ReportsVariants.Report.Name AS", "UNDEFINED AS");
			QueryText = StrReplace(QueryText, "ReportsVariants.VariantKey AS", "UNDEFINED AS");
			QueryText = StrReplace(QueryText, "ReportsVariants.ReportType AS", "UNDEFINED AS");
		EndIf;
		
	Else
		
		QueryText =
		"SELECT ALLOWED
		|	ReportsVariants.Ref AS Ref,
		|	ReportsVariants.VariantKey,
		|	ReportsVariants.Parent,
		|	ReportsVariants.Description,
		|	ReportsVariants.Definition
		|FROM
		|	Catalog.ReportsVariants AS ReportsVariants
		|WHERE
		|	ReportsVariants.ReportType IN(&ReportsTypes)
		|	AND ReportsVariants.Report IN(&UserReporting)
		|	AND Not ReportsVariants.PredefinedVariant IN (&DisabledApplicationOptions)
		|	AND ReportsVariants.DeletionMark = FALSE";
		
		If FilterByReportsTypesExist Then
			Query.SetParameter("ReportsTypes", SearchParameters.ReportsTypes);
		Else
			QueryText = StrReplace(
				QueryText,
				"ReportsVariants.ReportType IN(&ReportsTypes)
		|	AND",
				"");
		EndIf;
		
		If HasFilterByDeletionMark Then
			If SearchParameters.DeletionMark <> False Then
				QueryText = StrReplace(QueryText, ".DeletionMark = FALSE", ".DeletionMark = TRUE");
			EndIf;
		Else
			QueryText = StrReplace(QueryText, "
			|	AND ReportsVariants.DeletionMark = FALSE", "");
		EndIf;
		
	EndIf;
	
	Query.Text = QueryText;
	
	Result = New Structure;
	Result.Insert("Refs", New Array);
	Result.Insert("HighlightOptions", New Map);
	Result.Insert("Subsystems", New Array);
	Result.Insert("SubsystemsHighlight", New Map);
	Result.Insert("VariantsConnectedToSubsystems", New Map);
	
	ValueTable = Query.Execute().Unload();
	If ReceiveSummaryTable Then
		Result.Insert("ValueTable", ValueTable);
	EndIf;
	
	If ValueTable.Count() = 0 Then
		Return Result;
	EndIf;
	
	If Not HasSearchString Then
		VariantTable = ValueTable.Copy(, "Ref, Parent");
		VariantTable.GroupBy("Ref, Parent");
		For Each TableRow IN VariantTable Do
			If ValueIsFilled(TableRow.Ref) AND Result.Refs.Find(TableRow.Ref) = Undefined Then
				Result.Refs.Add(TableRow.Ref);
				If ValueIsFilled(TableRow.Parent) AND Result.Refs.Find(TableRow.Parent) = Undefined Then
					Result.Refs.Add(TableRow.Parent);
				EndIf;
			EndIf;
		EndDo;
		Return Result;
	EndIf;
	
	ValueTable.Sort("Ref");
	
	TemplateSearchAreas = New FixedStructure("Value, FoundWordsCount, HighlightWords", "", 0, New ValueList);
	
	TableRow = ValueTable[0];
	Variant = New Structure;
	Variant.Insert("Ref", TableRow.Ref);
	Variant.Insert("Parent", TableRow.Parent);
	Variant.Insert("VariantName",                 New Structure(TemplateSearchAreas));
	Variant.Insert("Definition",                             New Structure(TemplateSearchAreas));
	Variant.Insert("FieldNames",                    New Structure(TemplateSearchAreas));
	Variant.Insert("ParametersAndFiltersNames",       New Structure(TemplateSearchAreas));
	Variant.Insert("UserSettingsNames", New Structure(TemplateSearchAreas));
	Variant.Insert("SubsystemNames",                New Structure(TemplateSearchAreas));
	Variant.Insert("Subsystems",                           New Array);
	Variant.Insert("AuthorPresentation",                  New Structure(TemplateSearchAreas));
	
	StorageDelimiter = ReportsVariantsClientServer.StorageDelimiter();
	SeparatorPresentation = ReportsVariantsClientServer.SeparatorPresentation();
	
	Quantity = ValueTable.Count();
	For IndexOf = 1 To Quantity Do
		// Filling in variables.
		If Not ValueIsFilled(Variant.VariantName.Value) AND ValueIsFilled(TableRow.VariantName) Then
			Variant.VariantName.Value = TableRow.VariantName;
		EndIf;
		If Not ValueIsFilled(Variant.Definition.Value) AND ValueIsFilled(TableRow.Definition) Then
			Variant.Definition.Value = TableRow.Definition;
		EndIf;
		If Not ValueIsFilled(Variant.FieldNames.Value) AND ValueIsFilled(TableRow.FieldNames) Then
			Variant.FieldNames.Value = TableRow.FieldNames;
		EndIf;
		If Not ValueIsFilled(Variant.ParametersAndFiltersNames.Value) AND ValueIsFilled(TableRow.ParametersAndFiltersNames) Then
			Variant.ParametersAndFiltersNames.Value = TableRow.ParametersAndFiltersNames;
		EndIf;
		If Not ValueIsFilled(Variant.AuthorPresentation.Value) AND ValueIsFilled(TableRow.AuthorPresentation) Then
			Variant.AuthorPresentation.Value = TableRow.AuthorPresentation;
		EndIf;
		If ValueIsFilled(TableRow.UserSettingPresentation) Then
			If Variant.UserSettingsNames.Value = "" Then
				Variant.UserSettingsNames.Value = TableRow.UserSettingPresentation;
			Else
				Variant.UserSettingsNames.Value = Variant.UserSettingsNames.Value
					+ SeparatorPresentation
					+ TableRow.UserSettingPresentation;
			EndIf;
		EndIf;
		If ValueIsFilled(TableRow.SubsystemDescription)
			AND Variant.Subsystems.Find(TableRow.Subsystem) = Undefined Then
			Variant.Subsystems.Add(TableRow.Subsystem);
			Subsystem = Result.SubsystemsHighlight.Get(TableRow.Subsystem);
			If Subsystem = Undefined Then
				Subsystem = New Structure;
				Subsystem.Insert("Ref", TableRow.Subsystem);
				Subsystem.Insert("SubsystemDescription", New Structure(TemplateSearchAreas));
				Subsystem.SubsystemDescription.Value = TableRow.SubsystemDescription;
				Subsystem.Insert("AllWordsFound", True);
				Subsystem.Insert("FoundWords", New Array);
				For Each Word IN ArrayOfWords Do
					If MarkWord(Subsystem.SubsystemDescription, Word) Then
						Subsystem.FoundWords.Add(Word);
					Else
						Subsystem.AllWordsFound = False;
					EndIf;
				EndDo;
				If Subsystem.AllWordsFound Then
					Result.Subsystems.Add(Subsystem.Ref);
				EndIf;
				Result.SubsystemsHighlight.Insert(Subsystem.Ref, Subsystem);
			EndIf;
			If Variant.SubsystemNames.Value = "" Then
				Variant.SubsystemNames.Value = TableRow.SubsystemDescription;
			Else
				Variant.SubsystemNames.Value = Variant.SubsystemNames.Value
					+ SeparatorPresentation
					+ TableRow.SubsystemDescription;
			EndIf;
		EndIf;
		
		If IndexOf < Quantity Then
			TableRow = ValueTable[IndexOf];
		EndIf;
		
		If IndexOf = Quantity Or TableRow.Ref <> Variant.Ref Then
			// Collected information about variant analysis.
			AllWordsFound = True;
			RelatedSubsystems = New Array;
			For Each Word IN ArrayOfWords Do
				WordFound = False;
				
				If MarkWord(Variant.VariantName, Word) Then
					WordFound = True;
				EndIf;
				
				If MarkWord(Variant.Definition, Word) Then
					WordFound = True;
				EndIf;
				
				If MarkWord(Variant.FieldNames, Word, True) Then
					WordFound = True;
				EndIf;
				
				If MarkWord(Variant.AuthorPresentation, Word, True) Then
					WordFound = True;
				EndIf;
				
				If MarkWord(Variant.ParametersAndFiltersNames, Word, True) Then
					WordFound = True;
				EndIf;
				
				If MarkWord(Variant.UserSettingsNames, Word, True) Then
					WordFound = True;
				EndIf;
				
				If Not WordFound Then
					For Each SubsystemRef IN Variant.Subsystems Do
						Subsystem = Result.SubsystemsHighlight.Get(SubsystemRef);
						If Subsystem.FoundWords.Find(Word) <> Undefined Then
							WordFound = True;
							RelatedSubsystems.Add(SubsystemRef);
						EndIf;
					EndDo;
				EndIf;
				
				If Not WordFound Then
					AllWordsFound = False;
					Break;
				EndIf;
			EndDo;
			
			If AllWordsFound Then // Result registration.
				Result.Refs.Add(Variant.Ref);
				Result.HighlightOptions.Insert(Variant.Ref, Variant);
				If RelatedSubsystems.Count() > 0 Then
					Result.VariantsConnectedToSubsystems.Insert(Variant.Ref, RelatedSubsystems);
				EndIf;
				If ValueIsFilled(Variant.Parent) AND Result.Refs.Find(Variant.Parent) = Undefined Then
					Result.Refs.Add(Variant.Parent);
				EndIf;
			EndIf;
			
			If IndexOf = Quantity Then
				Break;
			EndIf;
			
			// Zeroing variables.
			Variant = New Structure;
			Variant.Insert("Ref", TableRow.Ref);
			Variant.Insert("Parent", TableRow.Parent);
			Variant.Insert("VariantName",                 New Structure(TemplateSearchAreas));
			Variant.Insert("Definition",                             New Structure(TemplateSearchAreas));
			Variant.Insert("FieldNames",                    New Structure(TemplateSearchAreas));
			Variant.Insert("ParametersAndFiltersNames",       New Structure(TemplateSearchAreas));
			Variant.Insert("UserSettingsNames", New Structure(TemplateSearchAreas));
			Variant.Insert("SubsystemNames",                New Structure(TemplateSearchAreas));
			Variant.Insert("Subsystems",                           New Array);
			Variant.Insert("AuthorPresentation",                  New Structure(TemplateSearchAreas));
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// Finds the word and marks the location where it was found. Returns True if the word is found.
Function MarkWord(StructureWhere, Word, UseSeparator = False) Export
	If Left(StructureWhere.Value, 1) = "#" Then
		StructureWhere.Value = Mid(StructureWhere.Value, 2);
	EndIf;
	Result = "";
	BalanceInReg = Upper(StructureWhere.Value);
	Position = Find(BalanceInReg, Word);
	If Position = 0 Then
		Return False;
	EndIf;
	If StructureWhere.FoundWordsCount = 0 Then
		// Initialization of a variable that contains the directive for words highlight.
		StructureWhere.HighlightWords = New ValueList;
		// Focus scroll up to the meaningful word (found information).
		If UseSeparator Then
			StorageDelimiter = ReportsVariantsClientServer.StorageDelimiter();
			SeparatorPresentation = ReportsVariantsClientServer.SeparatorPresentation();
			SeparatorLength = StrLen(StorageDelimiter);
			While Position > 10 Do
				SeparatorPosition = Find(BalanceInReg, StorageDelimiter);
				If SeparatorPosition = 0 Then
					Break;
				EndIf;
				If SeparatorPosition < Position Then
					// Transfer fragment up to separator to the end of the area.
					StructureWhere.Value = (
						Mid(StructureWhere.Value, SeparatorPosition + SeparatorLength)
						+ StorageDelimiter
						+ Left(StructureWhere.Value, SeparatorPosition - 1)
					);
					BalanceInReg = (
						Mid(BalanceInReg, SeparatorPosition + SeparatorLength)
						+ StorageDelimiter
						+ Left(BalanceInReg, SeparatorPosition - 1)
					);
					// Update information about the word placement.
					Position = Position - SeparatorPosition - SeparatorLength + 1;
				Else
					Break;
				EndIf;
			EndDo;
			StructureWhere.Value = StrReplace(StructureWhere.Value, StorageDelimiter, SeparatorPresentation);
			BalanceInReg = StrReplace(BalanceInReg, StorageDelimiter, SeparatorPresentation);
			Position = Find(BalanceInReg, Word);
		EndIf;
	EndIf;
	// New word registration.
	StructureWhere.FoundWordsCount = StructureWhere.FoundWordsCount + 1;
	// Mark words.
	LeftPartLength = 0;
	WordLength = StrLen(Word);
	While Position > 0 Do
		StructureWhere.HighlightWords.Add(LeftPartLength + Position, "+");
		StructureWhere.HighlightWords.Add(LeftPartLength + Position + WordLength, "-");
		BalanceInReg = Mid(BalanceInReg, Position + WordLength);
		LeftPartLength = LeftPartLength + Position + WordLength - 1;
		Position = Find(BalanceInReg, Word);
	EndDo;
	Return True;
EndFunction

// Deletes temporary table from the query text.
Procedure DeleteTemporaryTable(QueryText, NameOfTemporaryTable)
	TemporaryTablePosition = Find(QueryText, "INTO " + NameOfTemporaryTable);
	LeftPart = "";
	RightPart = QueryText;
	While True Do
		SemicolonPosition = Find(RightPart, Chars.LF + ";");
		If SemicolonPosition = 0 Then
			Break;
		ElsIf SemicolonPosition > TemporaryTablePosition Then
			RightPart = Mid(RightPart, SemicolonPosition + 2);
			Break;
		Else
			LeftPart = LeftPart + Left(RightPart, SemicolonPosition + 1);
			RightPart = Mid(RightPart, SemicolonPosition + 2);
			TemporaryTablePosition = TemporaryTablePosition - SemicolonPosition - 1;
		EndIf;
	EndDo;
	QueryText = LeftPart + RightPart;
EndProcedure

// Exports text and query Parameters to XML.
Function QueryInXML(Query) Export
	Structure = New Structure("Text, Parameters");
	FillPropertyValues(Structure, Query);
	Return CommonUse.ValueToXMLString(Structure);
EndFunction

#EndRegion
 

