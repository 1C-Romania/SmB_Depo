#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions which are responsible for getting of the form settings.

// Get the form setting list for specified User user.
// 
// Parameters:
//   UserName - String - infobase user name for whom it
//                              is necessary to get the form settings.
// 
// Returned
//   value ValueList - The list of forms for which the passed user has the settings.
//
Function AllFormsSettings(UserName) Export
	
	FormsList = MetadataObjectsForms();
	
	// Addition of the standard forms to list.
	FormsList.Add("ExternalDataProcessor.StandardEventLogMonitor.Form.EventsJournal", 
		NStr("en='Standard. Event log';ru='Стандартные.Журнал регистрации'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardEventLogMonitor.Form.EventForm", 
		NStr("en='Standard. Event log, Event';ru='Стандартные.Журнал регистрации, Событие'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardEventLogMonitor.Form.EventsJournalFilter", 
		NStr("en='Standard.Event log monitor, Events filter setup';ru='Стандартные.Журнал регистрации, Настройка отбора событий'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardFindByRef.Form.MainForm", 
		NStr("en='Standard.Search of references to object';ru='Стандартные.Поиск ссылок на объект'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardFullTextSearchManagement.Form.MainForm", 
		NStr("en='Standard.Full-text search management';ru='Стандартные.Управление полнотекстовым поиском'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardDocumentsPosting.Form.MainForm", 
		NStr("en='Standard.Document posting';ru='Стандартные.Проведение документов'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardMarkedObjectDeletion.Form.Form", 
		NStr("en='Standard.Deletion marked objects';ru='Стандартные.Удаление помеченных объектов'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardExternalDataSourceManagement.Form.Form", 
		NStr("en='Standard.External data source management';ru='Стандартные.Управление внешними источниками данных'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardTotalsManagement.Form.MainForm", 
		NStr("en='Standard.Totals management';ru='Стандартные.Управление итогами'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardActiveUsers.Form.ActiveUsersListForm", 
		NStr("en='Standard.Active users';ru='Стандартные.Активные пользователи'") , False, PictureLib.Form);
		
	Return FormsSettingsList(FormsList, UserName);
	
EndFunction

// Gets the list of forms in configuration, at that the fields are filled out as follows:
// Value - the form name that identifies it.
// Presentation - form synonym.
// Picture - picture corresponding to object which form is related to.
//
// Parameters:
// List - ValueList - the value list where the form descriptions will be added.
//
// Returned
// value ValueList - List of all metadata object forms.
//
Function MetadataObjectsForms()
	
	FormsList = New ValueList;
	
	For Each Form IN Metadata.CommonForms Do
		FormsList.Add("CommonForm." + Form.Name, Form.Synonym, False, PictureLib.Form);
	EndDo;

	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form");
	GetFormListOfMetadataObject(Metadata.FilterCriteria, "FilterCriterion", NStr("en='Filter criterion';ru='Критерий отбора'"),
		StandardFormNames, PictureLib.FilterCriterion, FormsList);
		
	StandardFormNames = New ValueList;
	GetFormListOfMetadataObject(Metadata.SettingsStorages, "SettingsStorage", NStr("en='Settings storage';ru='Хранилище настроек'"),
		StandardFormNames, PictureLib.SettingsStorage, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("FolderForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm");
	StandardFormNames.Add("FolderChoiceForm");
	GetFormListOfMetadataObject(Metadata.Catalogs, "Catalog", NStr("en='Catalog';ru='Справочник'"),
		StandardFormNames, PictureLib.Catalog, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm");
	GetFormListOfMetadataObject(Metadata.Documents, "Document", NStr("en='Document';ru='документ'"),
		StandardFormNames, PictureLib.Document, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form");
	GetFormListOfMetadataObject(Metadata.DocumentJournals, "DocumentJournal", NStr("en='Documents journal';ru='Журнал документов'"),
		StandardFormNames, PictureLib.DocumentJournal, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm");
	GetFormListOfMetadataObject(Metadata.Enums, "Enum", NStr("en='Enum';ru='Перечисление'"),
		StandardFormNames, PictureLib.Enum, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form");
	StandardFormNames.Add("SettingsForm");
	StandardFormNames.Add("VariantForm");
	GetFormListOfMetadataObject(Metadata.Reports, "Report", NStr("en='Report';ru='Отчет'"),
		StandardFormNames, PictureLib.Report, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form");
	GetFormListOfMetadataObject(Metadata.DataProcessors, "DataProcessor", NStr("en='DataProcessor';ru='Обработка'"),
		StandardFormNames, PictureLib.DataProcessor, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("FolderForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm");
	StandardFormNames.Add("FolderChoiceForm");
	GetFormListOfMetadataObject(Metadata.ChartsOfCharacteristicTypes, "ChartOfCharacteristicTypes", NStr("en='Chart of characteristic types';ru='План видов характеристик'"),
		StandardFormNames, PictureLib.ChartOfCharacteristicTypes, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm");
	GetFormListOfMetadataObject(Metadata.ChartsOfAccounts, "ChartOfAccounts", NStr("en='Chart of accounts';ru='План счетов'"),
		StandardFormNames, PictureLib.ChartOfAccounts, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm");
	GetFormListOfMetadataObject(Metadata.ChartsOfCalculationTypes, "ChartOfCalculationTypes", NStr("en='Chart of calculation types';ru='План видов расчета'"),
		StandardFormNames, PictureLib.ChartOfCalculationTypes, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("RecordForm");
	StandardFormNames.Add("ListForm");
	GetFormListOfMetadataObject(Metadata.InformationRegisters, "InformationRegister", NStr("en='Information register';ru='Регистр сведений'"),
		StandardFormNames, PictureLib.InformationRegister, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm");
	GetFormListOfMetadataObject(Metadata.AccumulationRegisters, "AccumulationRegister", NStr("en='Accumulation register';ru='Регистр накопления'"),
		StandardFormNames, PictureLib.AccumulationRegister, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm");
	GetFormListOfMetadataObject(Metadata.AccountingRegisters, "AccountingRegister", NStr("en='Accounting register';ru='Регистр бухгалтерии'"),
		StandardFormNames, PictureLib.AccountingRegister, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm");
	GetFormListOfMetadataObject(Metadata.CalculationRegisters, "CalculationRegister", NStr("en='Calculation register';ru='Регистр расчета'"),
		StandardFormNames, PictureLib.CalculationRegister, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm");
	GetFormListOfMetadataObject(Metadata.BusinessProcesses, "BusinessProcess", NStr("en='Business process';ru='Бизнес-процесс'"),
		StandardFormNames, PictureLib.BusinessProcess, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm");
	GetFormListOfMetadataObject(Metadata.Tasks, "Task", NStr("en='Task';ru='Задача'"),
		StandardFormNames, PictureLib.Task, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("RecordForm");
	StandardFormNames.Add("ListForm");
	GetFormListOfMetadataObject(Metadata.ExternalDataSources, "ExternalDataSource", NStr("en='External data sources';ru='Внешние источники данных'"),
		StandardFormNames, PictureLib.ExternalDataSourceTable, FormsList);

	Return FormsList;
EndFunction

// Returns the setting list for specified FormList forms and User user. 
//
Function FormsSettingsList(FormsList, UserName)
	
	Result = New ValueList;
	Settings = SettingsReadingFromStorage(SystemSettingsStorage, UserName);
	FormsSettingsArray = PredefinedSettings();
	For Each Item IN FormsList Do
		
		For Each SettingForms IN FormsSettingsArray Do
		
			SettingSearch = Settings.Find(Item.Value + SettingForms);
			If SettingSearch <> Undefined Then
				Result.Add(Item.Value, Item.Presentation, Item.Check, Item.Picture);
				Break;
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return Result;
	
EndFunction

Procedure GetFormListOfMetadataObject(MetadataObjectList, MetadataObjectType,
	MetadataObjectPresentation, StandardFormNames, Picture, FormsList)
	
	For Each Object IN MetadataObjectList Do
		
		If MetadataObjectType = "ExternalDataSource" Then
			GetExternalDataSourcesFormsList(Object, MetadataObjectType, MetadataObjectPresentation, Picture, FormsList);
			Continue;
		EndIf;
		
		NamePrefix = MetadataObjectType + "." + Object.Name;
		PresentationPrefix = Object.Synonym + ".";
		
		For Each Form IN Object.Forms Do
			FormPresentationAndMark = FormPresentation(Object, Form, MetadataObjectType);
			FormPresentation = FormPresentationAndMark.FormName;
			Check = FormPresentationAndMark.FormIsOpenable;
			FormsList.Add(NamePrefix + ".Form." + Form.Name, PresentationPrefix + FormPresentation, Check, Picture);
		EndDo;
		
		For Each StandardFormName IN StandardFormNames Do
			
			If Object["Default" + StandardFormName] = Undefined Then
				FormPresentationAndMark = AutogeneratedFormPresentation(Object, StandardFormName.Value, MetadataObjectType);
				FormPresentation = FormPresentationAndMark.FormName;
				Check = FormPresentationAndMark.FormIsOpenable;
				FormsList.Add(NamePrefix + "." + StandardFormName.Value, PresentationPrefix + FormPresentation, Check, Picture);
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure GetExternalDataSourcesFormsList(Object, MetadataObjectType, 
	MetadataObjectPresentation, Picture, FormsList)
	
	For Each Table IN Object.Tables Do
		
		NamePrefix = MetadataObjectType + "." + Object.Name + ".Table.";
		PresentationPrefix = Table.Synonym + ".";
		
		For Each Form IN Table.Forms Do
			FormPresentation = FormPresentation(Table, Form, MetadataObjectType).FormName;
			FormsList.Add(NamePrefix + Table.Name + ".Form." + Form.Name, PresentationPrefix + FormPresentation, False, Picture);
		EndDo;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions that are responsible for copy and deletion of all user settings.

// Deletes the user settings from storage.
//
// Parameters:
// ClearedSettings - Array where the array item - type of settings
//                      to be cleared. For example ReportsSettings or AppearanceSettings.
// Sources - Array where the array item - Catalog.UserRef. Array
//             of users that require settings clearing.
//
Procedure DeleteUserSettings(ClearedSettings, Sources, UserVariantsReportsTable = Undefined) Export
	
	MapStorageSetting = New Map;
	MapStorageSetting.Insert("ReportsSettings", ReportsUserSettingsStorage);
	MapStorageSetting.Insert("ExternalViewSettings", SystemSettingsStorage);
	MapStorageSetting.Insert("FormsData", FormDataSettingsStorage);
	MapStorageSetting.Insert("PersonalSettings", CommonSettingsStorage);
	MapStorageSetting.Insert("Favorites", SystemSettingsStorage);
	MapStorageSetting.Insert("PrintSettings", SystemSettingsStorage);
	
	For Each ClearedSetting IN ClearedSettings Do
		SettingsManager = MapStorageSetting[ClearedSetting];
		
		For Each Source IN Sources Do
			
			If ClearedSetting = "OtherUserSettings" Then
				// Getting user settings.
				UserInfo = New Structure;
				UserInfo.Insert("UserRef", Source);
				UserInfo.Insert("InfobaseUserName", IBUserName(Source));
				OtherUsersSettings = New Structure;
				UsersService.OnReceiveOtherSettings(UserInfo, OtherUsersSettings);
				Keys = New ValueList;
				ArrayOtherSettings = New Array;
				If OtherUsersSettings.Count() <> 0 Then
					
					For Each OtherSetting IN OtherUsersSettings Do
						OtherSettingsStructure = New Structure;
						If OtherSetting.Key = "QuickAccessSetup" Then
							SettingsList = OtherSetting.Value.SettingsList;
							For Each Item IN SettingsList Do
								Keys.Add(Item.Object, Item.ID);
							EndDo;
							OtherSettingsStructure.Insert("SettingID", "QuickAccessSetup");
							OtherSettingsStructure.Insert("SettingValue", Keys);
						Else
							OtherSettingsStructure.Insert("SettingID", OtherSetting.Key);
							OtherSettingsStructure.Insert("SettingValue", OtherSetting.Value.SettingsList);
						EndIf;
						
						UsersService.OnDeleteOtherSettings(UserInfo, OtherSettingsStructure);
					EndDo;
					
				EndIf;
				
				Continue;
			EndIf;
			
			Source = IBUserName(Source);
			
			If ClearedSetting = "ReportSettings" Then
				
				If UserVariantsReportsTable = Undefined Then
					UserVariantsReportsTable = UserReportsVariants(Source);
				EndIf;
				
				For Each ReportVariant IN UserVariantsReportsTable Do
					
					StandardProcessing = True;
					UsersService.WhenYouDeleteCustomReportVariants(ReportVariant, Source, StandardProcessing);
					If StandardProcessing Then
						ReportsVariantsStorage.Delete(ReportVariant.ObjectKey, ReportVariant.VariantKey, Source);
					EndIf;
					
				EndDo;
				
			EndIf;
			
			SettingsFromStorage = SettingsList(Source, SettingsManager, ClearedSetting);
			DeleteSettings(SettingsManager, SettingsFromStorage, Source);
			
			UsersService.SetInitialSettings(Source);
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure DeleteSettings(SettingsManager, SettingsFromStorage, UserName)
	
	For Each Setting IN SettingsFromStorage Do
		ObjectKey = Setting.ObjectKey;
		SettingsKey = Setting.SettingsKey;
		SettingsManager.Delete(ObjectKey, SettingsKey, UserName);
	EndDo;
	
EndProcedure

Function UserSettingsCopying(UserSourceRef, UsersTarget, CopiedSettings,
										NotCopiedReportsSettings = Undefined) Export
	
	MapStorageSetting = New Map;
	MapStorageSetting.Insert("ReportSettings", ReportsUserSettingsStorage);
	MapStorageSetting.Insert("ExternalViewSettings", SystemSettingsStorage);
	MapStorageSetting.Insert("FormsData", FormDataSettingsStorage);
	MapStorageSetting.Insert("PersonalSettings", CommonSettingsStorage);
	MapStorageSetting.Insert("Favorites", SystemSettingsStorage);
	MapStorageSetting.Insert("PrintSettings", SystemSettingsStorage);
	MapStorageSetting.Insert("ReportsVariants", ReportsVariantsStorage);
	IsSettings = False;
	ReportVariantsTable = Undefined;
	UserSource = IBUserName(UserSourceRef);
	
	// Getting user settings.
	UserInfo = New Structure;
	UserInfo.Insert("UserRef", UserSourceRef);
	UserInfo.Insert("InfobaseUserName", UserSource);
	OtherUsersSettings = New Structure;
	UsersService.OnReceiveOtherSettings(UserInfo, OtherUsersSettings);
	Keys = New ValueList;
	ArrayOtherSettings = New Array;
	If OtherUsersSettings.Count() <> 0 Then
		
		For Each OtherSetting IN OtherUsersSettings Do
			OtherSettingsStructure = New Structure;
			If OtherSetting.Key = "QuickAccessSetup" Then
				SettingsList = OtherSetting.Value.SettingsList;
				For Each Item IN SettingsList Do
					Keys.Add(Item.Object, Item.ID);
				EndDo;
				OtherSettingsStructure.Insert("SettingID", "QuickAccessSetup");
				OtherSettingsStructure.Insert("SettingValue", Keys);
			Else
				OtherSettingsStructure.Insert("SettingID", OtherSetting.Key);
				OtherSettingsStructure.Insert("SettingValue", OtherSetting.Value.SettingsList);
			EndIf;
			ArrayOtherSettings.Add(OtherSettingsStructure);
		EndDo;
		
	EndIf;
	
	For Each CopiedSetting IN CopiedSettings Do
		SettingsManager = MapStorageSetting[CopiedSetting];
		
		If CopiedSetting = "OtherUserSettings" Then
			For Each UserTarget IN UsersTarget Do
				UserInfo = New Structure;
				UserInfo.Insert("UserRef", UserTarget);
				UserInfo.Insert("InfobaseUserName", IBUserName(UserTarget));
				For Each ArrayElement IN ArrayOtherSettings Do
					UsersService.OnSaveOtherSetings(UserInfo, ArrayElement);
				EndDo;
			EndDo;
			Continue;
		EndIf;
		
		If CopiedSetting = "ReportSettings" Then
			
			If TypeOf(MapStorageSetting["ReportsVariants"]) = Type("StandardSettingsStorageManager") Then
				ReportVariantsTable = UserReportsVariants(UserSource);
				KeysAndReportVariantsTypesTable = KeyReportVariantsReceiving(ReportVariantsTable);
				CopiedSettings.Add("ReportsVariants");
			EndIf;
			
		EndIf;
		
		SettingsFromStorage = SettingsList(
			UserSource, SettingsManager, CopiedSetting, KeysAndReportVariantsTypesTable, True);
		
		If SettingsFromStorage.Count() <> 0 Then
			IsSettings = True;
		EndIf;
		
		For Each UserTarget IN UsersTarget Do
			CopySettings(
				SettingsManager, SettingsFromStorage, UserSource, UserTarget, NotCopiedReportsSettings);
			ReportVariantsTable = Undefined;
		EndDo;
		
	EndDo;
	
	Return IsSettings;
	
EndFunction

Function SettingsList(UserName, SettingsManager, 
						CopiedSetting, KeysAndReportVariantsTypesTable = Undefined, ForCopying = False)
	
	GetFavorites = False;
	GetPrintSettings = False;
	If CopiedSetting = "Favorites" Then
		GetFavorites = True;
	EndIf;
	
	If CopiedSetting = "PrintSettings" Then
		GetPrintSettings = True;
	EndIf;
	
	SettingsTable = New ValueTable;
	SettingsTable.Columns.Add("ObjectKey");
	SettingsTable.Columns.Add("SettingsKey");
	
	Filter = New Structure;
	Filter.Insert("User", UserName);
	
	SelectionSettings = SettingsManager.Select(Filter);
	
	Skip = False;
	While NextSetting(SelectionSettings, Skip) Do
		
		If Skip Then
			Continue;
		EndIf;
		
		If Not GetFavorites
			AND Find(SelectionSettings.ObjectKey, "UserWorkFavorites") <> 0 Then
			Continue;
		ElsIf GetFavorites Then
			
			If Find(SelectionSettings.ObjectKey, "UserWorkFavorites") = 0 Then
				Continue;
			ElsIf Find(SelectionSettings.ObjectKey, "UserWorkFavorites") <> 0 Then
				AddRowToTableValues(SettingsTable, SelectionSettings);
				Continue;
			EndIf;
			
		EndIf;
		
		If Not GetPrintSettings
			AND Find(SelectionSettings.ObjectKey, "SpreadsheetDocumentPrintSettings") <> 0 Then
			Continue;
		ElsIf GetPrintSettings Then
			
			If Find(SelectionSettings.ObjectKey, "SpreadsheetDocumentPrintSettings") = 0 Then
				Continue;
			ElsIf Find(SelectionSettings.ObjectKey, "SpreadsheetDocumentPrintSettings") <> 0 Then
				AddRowToTableValues(SettingsTable, SelectionSettings);
				Continue;
			EndIf;
			
		EndIf;
		
		If KeysAndReportVariantsTypesTable <> Undefined Then
			
			FoundReportVariant = KeysAndReportVariantsTypesTable.Find(SelectionSettings.ObjectKey, "VariantKey");
			If FoundReportVariant <> Undefined Then
				
				If Not FoundReportVariant.Check Then
					Continue;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If ForCopying AND SkipSetting(SelectionSettings.ObjectKey, SelectionSettings.SettingsKey) Then
			Continue;
		EndIf;
		
		AddRowToTableValues(SettingsTable, SelectionSettings);
	EndDo;
	
	Return SettingsTable;
	
EndFunction

Function NextSetting(SelectionSettings, Skip)
	
	Try 
		Skip = False;
		Return SelectionSettings.Next();
	Except
		Skip = True;
		Return True;
	EndTry;
	
EndFunction

Procedure CopySettings(SettingsManager, SettingsTable, UserSource,
								UserTarget, NotCopiedReportsSettings)
	
	UserIBRecipient = IBUserName(UserTarget);
	CurrentUser = Undefined;
	For Each Setting IN SettingsTable Do
		
		ObjectKey = Setting.ObjectKey;
		SettingKey = Setting.SettingsKey;
		
		If SettingsManager = ReportsUserSettingsStorage
			Or SettingsManager = ReportsVariantsStorage Then
			
			AvailiableReportsArray = ReportsAvailiableToUser(UserIBRecipient);
			ReportKey = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ObjectKey, "/");
			If AvailiableReportsArray.Find(ReportKey[0]) = Undefined Then
				
				If SettingsManager = ReportsUserSettingsStorage
					AND NotCopiedReportsSettings <> Undefined Then
					
					If CurrentUser = Undefined Then
						TableRow = NotCopiedReportsSettings.Add();
						TableRow.User = UserTarget.Description;
						CurrentUser = UserTarget.Description;
					EndIf;
					
					If TableRow.ReportList.FindByValue(ReportKey[0]) = Undefined Then
						TableRow.ReportList.Add(ReportKey[0]);
					EndIf;
					
				EndIf;
				
				Continue;
			EndIf;
			
		EndIf;
		
		Try
			Value = SettingsManager.Load(ObjectKey, SettingKey, , UserSource);
		Except
			Continue;
		EndTry;
		SettingsDescription = SettingsManager.GetDescription(ObjectKey, SettingKey, UserSource);
		SettingsManager.Save(ObjectKey, SettingKey, Value,
			SettingsDescription, UserIBRecipient);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions that are responsible for copy and deletion of selected settings.

// Copies the user settings of reports.
// 
// Parameters:
// UserSource - String - Name of the infobase user whose settings are taken for copy.
// UsersTarget - Items array UserRef - User who should copy
//                        selected settings.
// SettingsToCopyArray - Array - array item - ValueList containing the
//                                         selected setting keys.
//
Procedure CopyReportsSettingsAndPersonalSettings(SettingsManager, UserSource,
		UsersTarget, SettingsToCopyArray, NotCopiedReportsSettings = Undefined) Export
	
	For Each UserTarget IN UsersTarget Do
		CurrentUser = Undefined;
		
		For Each Item IN SettingsToCopyArray Do
				
			For Each SettingsItem IN Item Do
				
				SettingsKey = SettingsItem.Presentation;
				ObjectKey = SettingsItem.Value;
				If SkipSetting(ObjectKey, SettingsKey) Then
					Continue;
				EndIf;
				Setting = SettingsManager.Load(ObjectKey, SettingsKey, , UserSource);
				SettingDetails = SettingsManager.GetDescription(ObjectKey, SettingsKey, UserSource);
				
				If Setting <> Undefined Then
					
					UserIBRecipient = DataProcessors.UserSettings.IBUserName(UserTarget);
					
					If SettingsManager = ReportsUserSettingsStorage Then
						AvailiableReportsArray = ReportsAvailiableToUser(UserIBRecipient);
						ReportKey = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ObjectKey, "/");
						
						If AvailiableReportsArray.Find(ReportKey[0]) = Undefined Then
							
							If CurrentUser = Undefined Then
								TableRow = NotCopiedReportsSettings.Add();
								TableRow.User = UserTarget.Description;
								CurrentUser = UserTarget.Description;
							EndIf;
							
							If TableRow.ReportList.FindByValue(ReportKey[0]) = Undefined Then
								TableRow.ReportList.Add(ReportKey[0]);
							EndIf;
								
							Continue;
						EndIf;
						
					EndIf;
					
					SettingsManager.Save(ObjectKey, SettingsKey, Setting, SettingDetails, UserIBRecipient);
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Copies the apperance settings.
// 
// Parameters:
// UserSource - String - Name of the infobase user whose settings are taken for copy.
// UsersTarget - Items array UserRef - User who should copy
//                        selected settings.
// SettingsToCopyArray - Array - array item - ValueList containing the
//                                         selected setting keys.
//
Procedure CopyExternalViewSettings(UserSource, UsersTarget, SettingsToCopyArray) Export
	FormsSettingsArray = PredefinedSettings();
	
	For Each Item IN SettingsToCopyArray Do
		
		For Each SettingsItem IN Item Do
			SettingsKey = SettingsItem.Presentation;
			ObjectKey = SettingsItem.Value;
			
			If SettingsKey = "Interface"
				Or SettingsKey = "Other" Then
				CopyDesktopSettings(ObjectKey, UserSource, UsersTarget);
				Continue;
			EndIf;
			
			For Each Item IN FormsSettingsArray Do
				Setting = SystemSettingsStorage.Load(ObjectKey + Item, SettingsKey, , UserSource);
				
				If Setting <> Undefined Then
					
					For Each UserTarget IN UsersTarget Do
						UserIBRecipient = DataProcessors.UserSettings.IBUserName(UserTarget);
						SystemSettingsStorage.Save(ObjectKey + Item, SettingsKey, Setting, , UserIBRecipient);
					EndDo;
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure CopyDesktopSettings(ObjectKey, UserSource, UsersTarget)
	
	Setting = SystemSettingsStorage.Load(ObjectKey, "", , UserSource);
	If Setting <> Undefined Then
		
		For Each UserTarget IN UsersTarget Do
			UserIBRecipient = DataProcessors.UserSettings.IBUserName(UserTarget);
			SystemSettingsStorage.Save(ObjectKey, "", Setting, , UserIBRecipient);
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure DeleteSelectedUserSettings(Users, SettingsForDeletionArray, NameStore) Export
	
	For Each User IN Users Do
		User = DataProcessors.UserSettings.IBUserName(User);
		DeleteSelectedSettings(User, SettingsForDeletionArray, NameStore);
	EndDo;
	
EndProcedure

// Deletes the selected settings.
// 
// Parameters:
// User - String - Name of the infobase user for whom it is necessary to delete the settings.
// SettingsForDeletionArray - Array - array item - ValueList containing the selected setting keys.
// NameStore - String - name of the storage from which it is necessary to delete the settings.
//
Procedure DeleteSelectedSettings(UserName, SettingsForDeletionArray, StorageName) Export
	
	SettingsManager = SettingsStorageByName(StorageName);
	If StorageName = "ReportsUserSettingsStorage" Or StorageName = "CommonSettingsStorage" Then
		
		For Each Item IN SettingsForDeletionArray Do
			
			For Each Setting IN Item Do
				SettingsManager.Delete(Setting.Value, Setting.Presentation, UserName);
			EndDo;
			
		EndDo;
		
	ElsIf StorageName = "SystemSettingsStorage" Then
		
		SetInitialSettings = False;
		FormsSettingsArray = PredefinedSettings();
		
		For Each Item IN SettingsForDeletionArray Do
			
			For Each Setting IN Item Do
				
				If Setting.Presentation = "Interface" Or Setting.Presentation = "Other" Then
					
					SettingsManager.Delete(Setting.Value, , UserName);
					
					If Setting.Value = "Common/ClientApplicationSettings" 
						Or Setting.Value = "Common/SectionsPanel/CommandInterfaceSettings" 
						Or Setting.Value = "Common/ClientApplicationInterfaceSettings" Then
						
						SetInitialSettings = True;
						
					EndIf;
					
				Else
					
					For Each FormsItem IN FormsSettingsArray Do
						SettingsManager.Delete(Setting.Value + FormsItem, Setting.Presentation, UserName);
					EndDo;
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
		If SetInitialSettings Then
			UsersService.SetInitialSettings(UserName);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure DeleteReportsVariants(OptionsArrayReports, UserVariantsReportsTable, InfobaseUser) Export
	
	For Each Setting IN OptionsArrayReports Do
		
		ObjectKey = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Setting[0].Value, "/");
		ReportKey = ObjectKey[0];
		VariantKey = ObjectKey[1];
		
		FilterParameters = New Structure("VariantKey", VariantKey);
		FoundReportVariant = UserVariantsReportsTable.FindRows(FilterParameters);
		
		If FoundReportVariant.Count() = 0 Then
			Continue;
		EndIf;
		
		StandardProcessing = True;
		UsersService.WhenYouDeleteCustomReportVariants(FoundReportVariant[0], InfobaseUser, StandardProcessing);
		If StandardProcessing Then
			ReportsVariantsStorage.Delete(ReportKey, VariantKey, InfobaseUser);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CopyReportsVariants(OptionsArrayReports, UserVariantsReportsTable,
										InfobaseUser, ReceiversUsers) Export
		
		If TypeOf(InfobaseUser) <> Type("String") Then
			InfobaseUser = IBUserName(InfobaseUser);
		EndIf;
		
		For Each Setting IN OptionsArrayReports Do
		
		ObjectKey = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Setting[0].Value, "/");
		ReportKey = ObjectKey[0];
		VariantKey = ObjectKey[1];
		
		FilterParameters = New Structure("VariantKey", VariantKey);
		FoundReportVariant = UserVariantsReportsTable.FindRows(FilterParameters);
		
		If FoundReportVariant[0].StandardProcessing Then
			
			Try
			Value = ReportsVariantsStorage.Load(ReportKey, VariantKey, , InfobaseUser);
			Except
				Continue;
			EndTry;
			SettingDetails = ReportsVariantsStorage.GetDescription(ReportKey, VariantKey, InfobaseUser);
			
			For Each SettingsReceiver IN ReceiversUsers Do
				SettingsReceiver = IBUserName(SettingsReceiver);
				ReportsVariantsStorage.Save(ReportKey, VariantKey, Value, SettingDetails, SettingsReceiver);
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for getting the list of users and user groups.

// Receives the list of users from the Users
// catalog skipping invalid users, unseparated users with delimiter enabled, and also users with an empty ID.
// 
// Parameters:
// UserSource - CatalogRef - User who should be removed from the summary user table.
// UsersTable - ValueTable - Table for writing of selected users.
// UserExternal - Boolean - If True then users are selected from the ExternalUsers catalog.
//
Function UsersForCopying(UserSource, UsersTable, UserExternal, Clearing = False) Export
	
	UsersList = ?(UserExternal, AllExternalUsersList(UserSource),
		AllUsersList(UserSource, Clearing));
	For Each UserRef IN UsersList Do
		UsersTableRow = UsersTable.Add();
		UsersTableRow.User = UserRef.User;
	EndDo;
	UsersTable.Sort("User Asc");
	
	Return UsersTable;
	
EndFunction

Function AllUsersList(UserSource, Clearing)
	
	SetPrivilegedMode(True);
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Users.Ref AS User
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Not Users.NotValid"
	+ ?(Clearing AND Not CommonUseReUse.DataSeparationEnabled(),"", Chars.LF + "	AND NOT Users.Service")
	+ ?(Clearing,"", Chars.LF + "	AND NOT Users.DeletionMark") + Chars.LF +
	"	AND Users.Ref
	|	<> &UserSource AND Users.InfobaseUserID <> &EmptyInfobaseUserID";
	Query.Parameters.Insert("UserSource", UserSource);
	Query.Parameters.Insert("EmptyInfobaseUserID", New UUID("00000000-0000-0000-0000-000000000000"));
	
	BeginTransaction();
	Try
		QueryResult = Query.Execute().Unload();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return QueryResult;
	
EndFunction

Function AllExternalUsersList(UserSource)
	
	SetPrivilegedMode(True);
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Users.Ref AS User
	|FROM
	|	Catalog.ExternalUsers AS Users
	|WHERE
	|	Not Users.NotValid
	|	AND Not Users.DeletionMark
	|	AND Users.Ref <> &UserSource
	|	AND Users.InfobaseUserID <> &EmptyInfobaseUserID";
	Query.Parameters.Insert("UserSource", UserSource);
	Query.Parameters.Insert("EmptyInfobaseUserID", New UUID("00000000-0000-0000-0000-000000000000"));
	
	BeginTransaction();
	Try
		QueryResult = Query.Execute().Unload();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return QueryResult;
	
EndFunction

// Forms the value tree of the user groups.
// 
// Parameters:
// GroupsTree - ValueTree - Tree which is filled by the user groups.
// UserExternal - Boolean - If True then users are selected from the ExternalUsersGroups catalog.
Procedure FillGroupsTree(GroupsTree, UserExternal) Export
	
	GroupsArray = New Array;
	ParentGroupsArray = New Array;
	GroupsListAndFullStaff = UsersGroups(UserExternal);
	UsersGroupsList = GroupsListAndFullStaff.UsersGroupsList;
	TableGroupsAndStaff = GroupsListAndFullStaff.TableGroupsAndStaff;
	
	If UserExternal Then
		EmptyGroup = Catalogs.ExternalUsersGroups.EmptyRef();
	Else
		EmptyGroup = Catalogs.UsersGroups.EmptyRef();
	EndIf;
	
	GenerateFilter(UsersGroupsList, EmptyGroup, GroupsArray);
	
	While GroupsArray.Count() > 0 Do
		ParentGroupsArray.Clear();
		
		For Each Group IN GroupsArray Do
			
			If Group.Parent = EmptyGroup Then
				GroupNewRow = GroupsTree.Rows.Add();
				GroupNewRow.Group = Group.Ref;
				GroupContent = UsersGroupsStaff(Group.Ref, UserExternal);
				FullGroupStaff = UsersGroupFullStaff(TableGroupsAndStaff, Group.Ref);
				GroupNewRow.Content = GroupContent;
				GroupNewRow.FullSaff = FullGroupStaff;
				GroupNewRow.Picture = 3;
			Else
				ParentGroup = GroupsTree.Rows.FindRows(New Structure("Group", Group.Parent), True);
				SubordinatedGroupsNewRow = ParentGroup[0].Rows.Add();
				SubordinatedGroupsNewRow.Group = Group.Ref;
				GroupContent = UsersGroupsStaff(Group.Ref, UserExternal);
				FullGroupStaff = UsersGroupFullStaff(TableGroupsAndStaff, Group.Ref);
				SubordinatedGroupsNewRow.Content = GroupContent;
				SubordinatedGroupsNewRow.FullSaff = FullGroupStaff;
				SubordinatedGroupsNewRow.Picture = 3;
			EndIf;
			
			ParentGroupsArray.Add(Group.Ref);
		EndDo;
		GroupsArray.Clear();
		
		For Each Item IN ParentGroupsArray Do
			GenerateFilter(UsersGroupsList, Item, GroupsArray);
		EndDo;
		
	EndDo;
	
EndProcedure

Function UsersGroups(UserExternal)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	UsersGroupsCatalog.Ref AS Ref,
	|	UsersGroupsCatalog.Parent AS Parent
	|FROM
	|	Catalog.UsersGroups AS UsersGroupsCatalog";
	If UserExternal Then 
		Query.Text = StrReplace(Query.Text, "Catalog.UsersGroups", "Catalog.ExternalUsersGroups");
	EndIf;
	
	UsersGroupsList = Query.Execute().Unload();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	UsersGroupsContents.UsersGroup AS UsersGroup,
	|	UsersGroupsContents.User AS User
	|FROM
	|	InformationRegister.UsersGroupsContents AS UsersGroupsContents
	|
	|ORDER BY
	|	UsersGroup";
	
	UsersGroupsContents = Query.Execute().Unload();
	
	TableGroupsAndStaff = UsersGroupsFullStaff(UsersGroupsContents);
	
	Return New Structure("UsersGroupsList, TableGroupsAndStaff",
							UsersGroupsList, TableGroupsAndStaff);
EndFunction

Function UsersGroupsFullStaff(UsersGroupsContents)
	
	TableGroupsAndStaff = New ValueTable;
	TableGroupsAndStaff.Columns.Add("Group");
	TableGroupsAndStaff.Columns.Add("Content");
	GroupContent = New ValueList;
	CurrentGroup = Undefined;
	
	For Each ContentRow IN UsersGroupsContents Do
		
		If TypeOf(ContentRow.UsersGroup) = Type("CatalogRef.UsersGroups")
			Or TypeOf(ContentRow.UsersGroup) = Type("CatalogRef.ExternalUsersGroups") Then
			
			If CurrentGroup <> ContentRow.UsersGroup 
				AND Not CurrentGroup = Undefined Then
				RowTableGroupsAndStaff = TableGroupsAndStaff.Add();
				RowTableGroupsAndStaff.Group = CurrentGroup;
				RowTableGroupsAndStaff.Content = GroupContent.Copy();
				GroupContent.Clear();
			EndIf;
			GroupContent.Add(ContentRow.User);
			
		CurrentGroup = ContentRow.UsersGroup;
		EndIf;
		
	EndDo;
	
	RowTableGroupsAndStaff = TableGroupsAndStaff.Add();
	RowTableGroupsAndStaff.Group = CurrentGroup;
	RowTableGroupsAndStaff.Content = GroupContent.Copy();
	
	Return TableGroupsAndStaff;
EndFunction

Function UsersGroupsStaff(GroupReference, UserExternal)
	
	GroupContent = New ValueList;
	For Each Item IN GroupReference.Content Do
		
		If UserExternal Then
			GroupContent.Add(Item.ExternalUser);
		Else
			GroupContent.Add(Item.User);
		EndIf;
		
	EndDo;
	
	Return GroupContent;
EndFunction

Function UsersGroupFullStaff(TableGroupsAndStaff, GroupReference)
	
	FullGroupStaff = TableGroupsAndStaff.FindRows(New Structure("Group", GroupReference));
	If FullGroupStaff.Count() <> 0 Then
		Return FullGroupStaff[0].Content;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// Creates the report array available to the passed user.
//
// Parameters:
//  InfobaseUser - String - name of the infobase user whose
//                                   access rights to report are checked.
//
// Returns:
//   Result - Array - report keys that are available to passed user.
//
Function ReportsAvailiableToUser(UserTarget)
	Result = New Array;
	
	SetPrivilegedMode(True);
	InfobaseUser = InfobaseUsers.FindByName(UserTarget);
	For Each ReportMetadata IN Metadata.Reports Do
		
		If AccessRight("view", ReportMetadata, InfobaseUser) Then
			Result.Add("Report." + ReportMetadata.Name);
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Gets the infobase user name by
// passed ref of the catalog.
// Parameters:
// UserRef - CatalogRef - User for whom
// it is necessary to get the name of infobase user.
//
// Returned
// value String - Infobase user name. If the IB user is not found - Undefined.
// 
Function IBUserName(UserRef) Export
	
	SetPrivilegedMode(True);
	InfobaseUserID = CommonUse.ObjectAttributeValue(UserRef, "InfobaseUserID");
	IBUser = InfobaseUsers.FindByUUID(InfobaseUserID);
	
	If IBUser <> Undefined Then
		Return IBUser.Name;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function PredefinedSettings()
	
	TaxiInterface = (ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi);
	
	FormsSettingsArray = New Array;
	FormsSettingsArray.Add("/FormSettings");
	If TaxiInterface Then
		FormsSettingsArray.Add("/Taxi/WindowSettings");
		FormsSettingsArray.Add("/Taxi/WebClientWindowSettings");
	Else
		FormsSettingsArray.Add("/WindowSettings");
		FormsSettingsArray.Add("/WebClientWindowSettings");
	EndIf;
	FormsSettingsArray.Add("/CurrentData");
	FormsSettingsArray.Add("/CurrentUserSettings");
	
	Return FormsSettingsArray;
EndFunction

Function FormPresentation(Object, Form, MetadataObjectType)
	
	FormIsOpenable = False;
	
	If MetadataObjectType = "FilterCriterion"
		Or MetadataObjectType = "DocumentJournal" Then
		
		If Form = Object.DefaultForm Then
			FormName = ListFormPresentation(Object);
			FormIsOpenable = True;
		Else 
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "AccumulationRegister"
		Or MetadataObjectType = "AccountingRegister"
		Or MetadataObjectType = "CalculationRegister" Then
		
		If Form = Object.DefaultListForm Then
			FormName = ListFormPresentation(Object);
			FormIsOpenable = True;
		Else 
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "InformationRegister" Then
		
		If Form = Object.DefaultRecordForm Then
			
			If Not IsBlankString(Object.ExtendedRecordPresentation) Then
				FormName = Object.ExtendedRecordPresentation;
			ElsIf Not IsBlankString(Object.RecordPresentation) Then
				FormName = Object.RecordPresentation;
			Else
				FormName = Object.Presentation();
			EndIf;
			
		ElsIf Form = Object.DefaultListForm Then
			FormName = ListFormPresentation(Object);
			FormIsOpenable = True;
		Else 
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "Report"
		Or MetadataObjectType = "DataProcessor" Then
		
		If Form = Object.DefaultForm Then
			If Not IsBlankString(Object.ExtendedPresentation) Then
				FormName = Object.ExtendedPresentation;
			Else
				FormName = Object.Presentation();
			EndIf;
			FormIsOpenable = True;
		Else
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "SettingsStorage" Then
		FormName = Form.Synonym;
	ElsIf MetadataObjectType = "Enum" Then
		
		If Form = Object.DefaultListForm
			Or Form = Object.DefaultChoiceForm Then
			FormName = ListFormPresentation(Object);
			FormIsOpenable = ?(Form = Object.DefaultListForm, True, False);
		Else
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "Catalog"
		Or MetadataObjectType = "ChartOfCharacteristicTypes" Then
		
		If Form = Object.DefaultListForm
			Or Form = Object.DefaultChoiceForm
			Or Form = Object.DefaultFolderForm 
			Or Form = Object.DefaultFolderChoiceForm Then
			
			FormName = ListFormPresentation(Object);
			AddFormTypeToPresentation(Object, Form, FormName);
			FormIsOpenable = ?(Form = Object.DefaultListForm, True, False);
			
		ElsIf Form = Object.DefaultObjectForm Then
			FormName = ObjectFormPresentation(Object);
		Else
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "ExternalDataSource" Then
		
		If Form = Object.DefaultListForm Then
			FormName = ListFormPresentation(Object);
			FormIsOpenable = True;
		ElsIf Form = Object.DefaultRecordForm Then
			
			If Not IsBlankString(Object.ExtendedRecordPresentation) Then
				FormName = Object.ExtendedRecordPresentation ;
			ElsIf Not IsBlankString(Object.RecordPresentation) Then
				FormName = Object.RecordPresentation;
			Else
				FormName = Object.Presentation();
			EndIf;
			
		ElsIf Form = Object.DefaultObjectForm Then
			ObjectFormPresentation(Object);
		Else
			FormName = Form.Synonym;
		EndIf;
		
	Else // Getting the presentation of form for Document, Chart of accounts, Chart of settlement kinds, Business processes and Tasks.
		
		If Form = Object.DefaultListForm
			Or Form = Object.DefaultChoiceForm Then
			FormName = ListFormPresentation(Object);
			FormIsOpenable = ?(Form = Object.DefaultListForm, True, False);
		ElsIf Form = Object.DefaultObjectForm Then
			FormName = ObjectFormPresentation(Object);
		Else
			FormName = Form.Synonym;
		EndIf;
		
	EndIf;
	
	Return New Structure("FormName, FormIsOpenable", FormName, FormIsOpenable);
	
EndFunction

Function AutogeneratedFormPresentation(Object, Form, MetadataObjectType)
	
	FormIsOpenable = False;
	
	If MetadataObjectType = "FilterCriterion"
		Or MetadataObjectType = "DocumentJournal" Then
		
		FormName = ListFormPresentation(Object);
		FormIsOpenable = True;
		
	ElsIf MetadataObjectType = "AccumulationRegister"
		Or MetadataObjectType = "AccountingRegister"
		Or MetadataObjectType = "CalculationRegister" Then
		
		FormName = ListFormPresentation(Object);
		FormIsOpenable = True;
		
	ElsIf MetadataObjectType = "InformationRegister" Then
		
		If Form = "RecordForm" Then
			
			If Not IsBlankString(Object.ExtendedRecordPresentation) Then
				FormName = Object.ExtendedRecordPresentation;
			ElsIf Not IsBlankString(Object.RecordPresentation) Then
				FormName = Object.RecordPresentation;
			Else
				FormName = Object.Presentation();
			EndIf;
			
		ElsIf Form = "ListForm" Then
			FormName = ListFormPresentation(Object);
			FormIsOpenable = True;
		EndIf;
		
	ElsIf MetadataObjectType = "Report"
		Or MetadataObjectType = "DataProcessor" Then
		
		If Not IsBlankString(Object.ExtendedPresentation) Then
			FormName = Object.ExtendedPresentation;
		Else
			FormName = Object.Presentation();
		EndIf;
		FormIsOpenable = True;
		
	ElsIf MetadataObjectType = "Enum" Then
		
		FormName = ListFormPresentation(Object);
		FormIsOpenable = ?(Form = "ListForm", True, False);
		
	ElsIf MetadataObjectType = "Catalog"
		Or MetadataObjectType = "ChartOfCharacteristicTypes" Then
		
		If Form = "ListForm"
			Or Form = "ChoiceForm"
			Or Form = "FolderForm" 
			Or Form = "FolderChoiceForm" Then
			FormName = ListFormPresentation(Object);
			AddPresentationFormAvtogeneriruemojForms(Object, Form, FormName);
			FormIsOpenable = ?(Form = "ListForm", True, False);
		ElsIf Form = "ObjectForm" Then
			FormName = ObjectFormPresentation(Object);
		EndIf;
		
	ElsIf MetadataObjectType = "ExternalDataSource" Then
		
		If Form = "ListForm" Then
			FormName = ListFormPresentation(Object);
			FormIsOpenable = True;
		ElsIf Form = "RecordForm" Then
			If Not IsBlankString(Object.ExtendedRecordPresentation) Then
				FormName = Object.ExtendedRecordPresentation ;
			ElsIf Not IsBlankString(Object.RecordPresentation) Then
				FormName = Object.RecordPresentation;
			Else
				FormName = Object.Presentation();
			EndIf;
		ElsIf Form = "ObjectForm" Then
			ObjectFormPresentation(Object);
		EndIf;
		
	Else // Getting the presentation of form for Document, Chart of accounts, Chart of settlement kinds, Business processes and Tasks.
		
		If Form = "ListForm"
			Or Form = "ChoiceForm" Then
			FormName = ListFormPresentation(Object);
			FormIsOpenable = ?(Form = "ListForm", True, False);
		ElsIf Form = "ObjectForm" Then
			FormName = ObjectFormPresentation(Object);
		EndIf;
		
	EndIf;
	
	Return New Structure("FormName, FormIsOpenable", FormName, FormIsOpenable);
	
EndFunction

Function ListFormPresentation(Object)
	
	If Not IsBlankString(Object.ExtendedListPresentation) Then
		FormName = Object.ExtendedListPresentation;
	ElsIf Not IsBlankString(Object.ListPresentation) Then
		FormName = Object.ListPresentation;
	Else
		FormName = Object.Presentation();
	EndIf;
	
	Return FormName;
EndFunction

Function ObjectFormPresentation(Object)
	
	If Not IsBlankString(Object.ExtendedObjectPresentation) Then
		FormName = Object.ExtendedObjectPresentation;
	ElsIf Not IsBlankString(Object.ObjectPresentation) Then
		FormName = Object.ObjectPresentation;
	Else
		FormName = Object.Presentation();
	EndIf;;
	
	Return FormName;
EndFunction

Procedure AddFormTypeToPresentation(Object, Form, FormName)
	
	If Form = Object.DefaultListForm Then
		FormName = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 (list)';ru='%1 (список)'"), FormName);
	ElsIf Form = Object.DefaultChoiceForm Then
		FormName = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 (choice)';ru='%1 (выбор)'"), FormName);
	ElsIf Form = Object.DefaultFolderForm Then
		FormName = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 (group)';ru='%1 (группа)'"), FormName);
	EndIf;
	
EndProcedure

Procedure AddPresentationFormAvtogeneriruemojForms(Object, Form, FormName)
	
	If Form = "ListForm" Then
		FormName = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 (list)';ru='%1 (список)'"), FormName);
	ElsIf Form = "ChoiceForm" Then
		FormName = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 (choice)';ru='%1 (выбор)'"), FormName);
	ElsIf Form = "FolderChoiceForm" Then
		FormName = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 (group)';ru='%1 (группа)'"), FormName);
	EndIf;
	
EndProcedure

Procedure AddRowToTableValues(SettingsTable, SelectionSettings)
	
	If Find(SelectionSettings.ObjectKey, "ExternalReport.") <> 0 Then
		Return;
	EndIf;
	
	NewRow = SettingsTable.Add();
	NewRow.ObjectKey = SelectionSettings.ObjectKey;
	NewRow.SettingsKey = SelectionSettings.SettingsKey;
	
EndProcedure

Function ReportVariantPresentation(SettingKey, VariantNameReport)
	
	ReportName = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(VariantNameReport[0], ".");
	Report = Metadata.Reports.Find(ReportName[1]);
	
	If Report = Undefined Then
		Return Undefined;
	EndIf;
	
	VariantsStorage = Report.VariantsStorage;
	
	If VariantsStorage = Undefined Then
		VariantsStorage = Metadata.ReportsVariantsStorage;
	EndIf;
	
	If VariantsStorage = Undefined Then
		VariantsStorage = ReportsVariantsStorage;
	Else
		VariantsStorage = SettingsStorages[VariantsStorage.Name];
	EndIf;
	
	If VariantNameReport.Count() = 1 Then
		VariantID = ReportName[1];
	Else
		VariantID = VariantNameReport[1];
	EndIf;
	
	ReportVariantPresentation = VariantsStorage.GetDescription(VariantNameReport[0], VariantID);
	
	If ReportVariantPresentation <> Undefined
		Then
		Return ReportVariantPresentation.Presentation;
	Else
		Return ReportName[1];
	EndIf;
	
EndFunction

Function SettingsReadingFromStorage(SettingsManager, User)
	
	Settings = New ValueTable;
	Settings.Columns.Add("ObjectKey");
	Settings.Columns.Add("SettingsKey");
	Settings.Columns.Add("Presentation");
	
	Filter = New Structure;
	Filter.Insert("User", User);
	
	Skip = False;
	SelectionSettings = SettingsManager.Select(Filter);
	While NextSetting(SelectionSettings, Skip) Do
		
		If Skip Then
			Continue;
		EndIf;
		
		NewRow = Settings.Add();
		NewRow.ObjectKey = SelectionSettings.ObjectKey;
		NewRow.SettingsKey = SelectionSettings.SettingsKey;
		NewRow.Presentation = SelectionSettings.Presentation;
		
	EndDo;
	
	Return Settings;
	
EndFunction

Function UserReportsVariants(InfobaseUser)
	
	ReportVariantsTable = New ValueTable;
	ReportVariantsTable.Columns.Add("ObjectKey");
	ReportVariantsTable.Columns.Add("VariantKey");
	ReportVariantsTable.Columns.Add("Presentation");
	ReportVariantsTable.Columns.Add("StandardProcessing"); 
	
	For Each ReportMetadata IN Metadata.Reports Do
		
		StandardProcessing = True;
		UsersService.OnObtainingCustomOptionsReports(ReportMetadata, InfobaseUser, ReportVariantsTable, StandardProcessing);
		If StandardProcessing Then
			ReportVariants = ReportsVariantsStorage.GetList("Report." + ReportMetadata.Name, InfobaseUser);
			For Each ReportVariant IN ReportVariants Do
				ReportVariantsRow = ReportVariantsTable.Add();
				ReportVariantsRow.ObjectKey = "Report." + ReportMetadata.Name;
				ReportVariantsRow.VariantKey = ReportVariant.Value;
				ReportVariantsRow.Presentation = ReportVariant.Presentation;
				ReportVariantsRow.StandardProcessing = True;
			EndDo;
		EndIf;
		
	EndDo;
	
	Return ReportVariantsTable;
	
EndFunction

Function UserSettingsKeys()
	
	KeyArray = New Array;
	KeyArray.Add("CurrentVariantKey");
	KeyArray.Add("CurrentUserSettingsKey");
	KeyArray.Add("CurrentUserSettings");
	KeyArray.Add("CurrentDataSettingsKey");
	KeyArray.Add("ClientSettings");
	KeyArray.Add("AddInSettings");
	KeyArray.Add("HelpSettings");
	KeyArray.Add("ComparisonSettings");
	KeyArray.Add("TableSearchParameters");
	
	Return KeyArray;
EndFunction

Function SettingsStorageByName(NameStore)
	
	If NameStore = "ReportsUserSettingsStorage" Then
		Return ReportsUserSettingsStorage;
	ElsIf NameStore = "CommonSettingsStorage" Then
		Return CommonSettingsStorage;
	Else
		Return SystemSettingsStorage;
	EndIf;
	
EndFunction

Procedure GenerateFilter(UsersGroupsList, GroupReference, GroupsArray)
	
	FilterParameters = New Structure("Parent", GroupReference);
	FilteredRows = UsersGroupsList.FindRows(FilterParameters);
	
	For Each Item IN FilteredRows Do 
		GroupsArray.Add(Item);
	EndDo;
	
EndProcedure

Function KeyReportVariantsReceiving(ReportVariantsTable)
	
	KeysAndReportVariantsTypesTable = New ValueTable;
	KeysAndReportVariantsTypesTable.Columns.Add("VariantKey");
	KeysAndReportVariantsTypesTable.Columns.Add("Check");
	For Each TableRow IN ReportVariantsTable Do
		ValueTableRow = KeysAndReportVariantsTypesTable.Add();
		ValueTableRow.VariantKey = TableRow.ObjectKey + "/" + TableRow.VariantKey;
		ValueTableRow.Check = TableRow.StandardProcessing;
	EndDo;
	
	Return KeysAndReportVariantsTypesTable;
EndFunction

Function CopyingReportGenerating(NOTCopiedReportsSettings,
										UserVariantsReportsTable = Undefined) Export
	
	Spreadsheet = New SpreadsheetDocument;
	TabTemplate = DataProcessors.UserSettings.GetTemplate("ReportTemplate");
	
	ReportIsNotVoid = False;
	If UserVariantsReportsTable <> Undefined
		AND UserVariantsReportsTable.Count() <> 0 Then
		HeaderArea = TabTemplate.GetArea("Title");
		HeaderArea.Parameters.Definition = NStr("en='
		|It is impossible to copy the personal variants of reports.
		|If you want to make personal report variant to
		|be available to other users, then you need to resave it with the ""Only for author"" mark removed.
		|List of the skipped report variants:';ru='
		|Невозможно скопировать личные варианты отчетов.
		|Для того чтобы личный вариант отчета стал
		|доступен другим пользователям, необходимо его пересохранить со снятой пометкой ""Только для автора"".
		|Список пропущенных вариантов отчетов:'");
		Spreadsheet.Put(HeaderArea);
		
		Spreadsheet.Put(TabTemplate.GetArea("IsBlankString"));
		
		AreaContent = TabTemplate.GetArea("ReportContent");
		
		For Each TableRow IN UserVariantsReportsTable Do
			
			If Not TableRow.StandardProcessing Then
				AreaContent.Parameters.Description = TableRow.Presentation;
				Spreadsheet.Put(AreaContent);
			EndIf;
			
		EndDo;
		
		ReportIsNotVoid = True;
	EndIf;
	
	If NotCopiedReportsSettings.Count() <> 0 Then
		HeaderArea = TabTemplate.GetArea("Title");
		HeaderArea.Parameters.Definition = NStr("en='
		|Following users have insufficient rights for the reports:';ru='
		|У следующих пользователй недостаточно прав на отчеты:'");
		Spreadsheet.Put(HeaderArea);
		
		AreaContent = TabTemplate.GetArea("ReportContent");
		
		For Each TableRow IN NotCopiedReportsSettings Do
			Spreadsheet.Put(TabTemplate.GetArea("IsBlankString"));
			AreaContent.Parameters.Description = TableRow.User + ":";
			Spreadsheet.Put(AreaContent);
			For Each ReportName IN TableRow.ReportList Do
				AreaContent.Parameters.Description = ReportName.Value;
				Spreadsheet.Put(AreaContent);
			EndDo;
			
		EndDo;
		
	ReportIsNotVoid = True;
	EndIf;
	
	If ReportIsNotVoid Then
		Report = New SpreadsheetDocument;
		Report.Put(Spreadsheet);
		
		Return Report;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function SkipSetting(ObjectKey, SettingsKey)
	
	ObjectKeyExceptions = New Array;
	SettingsKeyExceptions = New Array;
	
	// Exceptions. Settings that can not be copied.
	ObjectKeyExceptions.Add("LocalFilesCache");
	SettingsKeyExceptions.Add("PathToFilesLocalCache");
	
	If ObjectKeyExceptions.Find(ObjectKey) <> Undefined
		AND SettingsKeyExceptions.Find(SettingsKey) <> Undefined Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for the UsersSettings and SettingsChoice forms.

Procedure FillListsSettings(Form) Export
	
	FillReportsSettingsList(Form);
	FillExternalViewSettingsList(Form);
	FillOtherSettingsList(Form);
	
EndProcedure

Procedure FillReportsSettingsList(Form)
	
	FormName = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Form.FormName, ".");
	Form.ReportsSettings.GetItems().Clear();
	ReportsSettingsTree = Form.FormAttributeToValue("ReportsSettings");
	ReportVariantsTable = UserReportsVariants(Form.InfobaseUser);
	UserReportsVariants = Form.FormAttributeToValue("UserVariantsReportsTable");
	UserReportsVariants.Clear();
	UserReportsVariants = ReportVariantsTable.Copy();
	
	Settings = SettingsReadingFromStorage(
		ReportsUserSettingsStorage, Form.InfobaseUser);
	
	CurrentObject = Undefined;
	
	For Each Setting IN Settings Do
		SettingsObject = Setting.ObjectKey;
		SettingKey = Setting.SettingsKey;
		SettingName = Setting.Presentation;
		
		VariantNameReport = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(SettingsObject, "/");
		ReportVariantPresentation = ReportVariantPresentation(SettingKey, VariantNameReport);
		
		// If the report variant (report) was deleted but setting remained - do not display it to user.
		If ReportVariantPresentation = "" Then
			Continue;
		EndIf;
		
		// Check if it is the custom variant of report.
		FoundReportVariant = ReportVariantsTable.Find(VariantNameReport[1], "VariantKey");
		// If the setting selection form is opened, then hide the settings which can not be copied.
		If FormName[3] = "SettingsChoice"
			AND FoundReportVariant <> Undefined
			AND Not FoundReportVariant.StandardProcessing Then
			Continue;
		EndIf;
		
		If ReportVariantPresentation = Undefined Then
			Continue;
		EndIf;
		
		If Not IsBlankString(Form.Search) Then
			If Find(Upper(ReportVariantPresentation), Upper(Form.Search)) = 0
				AND Find(Upper(SettingName), Upper(Form.Search)) = 0 Then
				Continue;
			EndIf;
		EndIf;
		
		// Fill string of the report variant.
		If CurrentObject <> ReportVariantPresentation Then
			NewRowReportVariant = ReportsSettingsTree.Rows.Add();
			NewRowReportVariant.Setting = ReportVariantPresentation;
			NewRowReportVariant.Picture = PictureLib.Report;
			NewRowReportVariant.Type =
				?(FoundReportVariant <> Undefined, 
					?(NOT FoundReportVariant.StandardProcessing, "PersonalVariant", "StandardPersonalVariant"), "StandardReportVariant");
			NewRowReportVariant.RowType = "Report" + ReportVariantPresentation;
		EndIf;
		// Fill the setting string
		NewRowSetting = NewRowReportVariant.Rows.Add();
		NewRowSetting.Setting = ?(NOT IsBlankString(SettingName), SettingName, ReportVariantPresentation);
		NewRowSetting.Picture = PictureLib.Form;
		NewRowSetting.Type = 
			?(FoundReportVariant <> Undefined,
				?(NOT FoundReportVariant.StandardProcessing, "SettingPersonal", "StandardSettingPersonal"), "StandardReportSetting");
		NewRowSetting.RowType = ReportVariantPresentation + SettingName;
		NewRowSetting.Keys.Add(SettingsObject, SettingKey);
		// Fill the object key and the setting key for the report variant.
		NewRowReportVariant.Keys.Add(SettingsObject, SettingKey);
		
		CurrentObject = ReportVariantPresentation;
		
		// Delete reports with settings in the list of user variants.
		If FoundReportVariant <> Undefined Then
			ReportVariantsTable.Delete(FoundReportVariant);
		EndIf;
		
	EndDo;
	
	For Each ReportVariant IN ReportVariantsTable Do
		
		If FormName[3] = "SettingsChoice"
			AND Form.ActionWithSettings = "Copy"
			AND Not ReportVariant.StandardProcessing Then
			Continue;
		EndIf;
		
		If Not IsBlankString(Form.Search) Then
			
			If Find(Upper(ReportVariant.Presentation), Upper(Form.Search)) = 0 Then
				Continue;
			EndIf;
			
		EndIf;
		
		NewRowReportVariant = ReportsSettingsTree.Rows.Add();
		NewRowReportVariant.Setting = ReportVariant.Presentation;
		NewRowReportVariant.Picture = PictureLib.Report;
		NewRowReportVariant.Keys.Add(ReportVariant.ObjectKey + "/" + ReportVariant.VariantKey);
		NewRowReportVariant.Type = ?(NOT ReportVariant.StandardProcessing, "PersonalVariant", "StandardPersonalVariant");
		NewRowReportVariant.RowType = "Report" + ReportVariant.Presentation;
		
	EndDo;
	
	ReportsSettingsTree.Rows.Sort("Setting Asc", True);
	Form.ValueToFormAttribute(ReportsSettingsTree, "ReportsSettings");
	Form.ValueToFormAttribute(UserReportsVariants, "UserVariantsReportsTable");
	
EndProcedure

Procedure AddDesktopAndCommandInterfaceSettings(Form, SettingsTree)
	
	If Not IsBlankString(Form.Search) Then
		If Find(Upper(NStr("en='Desktop and command interface';ru='Рабочий стол и командный интерфейс'")), Upper(Form.Search)) = 0 Then
			Return;
		EndIf;
	EndIf;
	
	Settings = SettingsReadingFromStorage(SystemSettingsStorage, Form.InfobaseUser);
	DesktopSettingKeys = New ValueList;
	KeywordsSettingsInterface = New ValueList;
	AllSettingsKeys = New ValueList; 
	
	For Each Setting IN Settings Do
		SettingName = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Setting.ObjectKey, "/");
		SettingNamePart = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(SettingName[0], ".");
		If SettingNamePart[0] = "Subsystem" Then
			
			KeywordsSettingsInterface.Add(Setting.ObjectKey, "Interface");
			AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			
		ElsIf SettingName[0] = "Common" Then
			
			If SettingName[1] = "SectionsPanel"
				Or SettingName[1] = "ActionsPanel" 
				Or SettingName[1] = "ClientSettings" 
				Or SettingName[1] = "ClientApplicationInterfaceSettings" Then
				KeywordsSettingsInterface.Add(Setting.ObjectKey, "Interface");
				AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			ElsIf SettingName[1] = "DesktopSettings"
				Or SettingName[1] = "StartPageSettings" Then
				DesktopSettingKeys.Add(Setting.ObjectKey, "Interface");
				AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			EndIf;
			
		ElsIf SettingName[0] = "Desktop" Then
			
			If SettingName[1] = "WindowSettings" Then
				DesktopSettingKeys.Add(Setting.ObjectKey, "Interface");
				AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			Else
				KeywordsSettingsInterface.Add(Setting.ObjectKey, "Interface");
				AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If AllSettingsKeys.Count() > 0 Then
		// Addition of the top level group for desktop and interface settings.
		InterfaceNewRow = SettingsTree.Rows.Add();
		InterfaceNewRow.Setting = NStr("en='Desktop and command interface';ru='Рабочий стол и командный интерфейс'");
		InterfaceNewRow.Picture = PictureLib.Picture;
		InterfaceNewRow.RowType = NStr("en='Desktop and command interface';ru='Рабочий стол и командный интерфейс'");
		InterfaceNewRow.Type = "SettingExternalType";
		InterfaceNewRow.Keys = AllSettingsKeys.Copy();
	EndIf;
	
	If DesktopSettingKeys.Count() > 0 Then
		// Addition of the desktop setting string.
		NewInterfaceSubrow = InterfaceNewRow.Rows.Add();
		NewInterfaceSubrow.Setting = NStr("en='Desktop';ru='Рабочий стол'");
		NewInterfaceSubrow.Picture = PictureLib.Picture;
		NewInterfaceSubrow.RowType = "DesktopSettings";
		NewInterfaceSubrow.Type = "SettingExternalType";
		NewInterfaceSubrow.Keys = DesktopSettingKeys.Copy();
	EndIf;
	
	If KeywordsSettingsInterface.Count() > 0 Then
		// Addition of the interface setting string.
		NewInterfaceSubrow = InterfaceNewRow.Rows.Add();
		NewInterfaceSubrow.Setting = NStr("en='Command interface';ru='Командный интерфейс'");
		NewInterfaceSubrow.Picture = PictureLib.Picture;
		NewInterfaceSubrow.RowType = "CommandInterfaceSettings";
		NewInterfaceSubrow.Type = "SettingExternalType";
		NewInterfaceSubrow.Keys = KeywordsSettingsInterface.Copy();
	EndIf;
	
EndProcedure

Procedure FillExternalViewSettingsList(Form)
	
	Form.ExternalView.GetItems().Clear();
	ExternalViewSettings = Form.FormAttributeToValue("ExternalView");
	
	CurrentObject = Undefined;
	FormsSettings = AllFormsSettings(Form.InfobaseUser);
	
	For Each SettingForms IN FormsSettings Do
		MetadataObjectName = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(SettingForms.Value, ".");
		MetadataObjectPresentation = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(SettingForms.Presentation, ".");
		
		If Not IsBlankString(Form.Search) Then
			
			If Find(Upper(SettingForms.Presentation), Upper(Form.Search)) = 0 Then
				Continue;
			EndIf;
			
		EndIf;

		If MetadataObjectName[0] = "CommonForm" Then
			NewRowCommonForms = ExternalViewSettings.Rows.Add();
			NewRowCommonForms.Setting = SettingForms.Presentation;
			NewRowCommonForms.Picture = PictureLib.Form;
			NewRowCommonForms.Keys.Add(SettingForms.Value, "");
			NewRowCommonForms.Type = "SettingExternalType";
			NewRowCommonForms.RowType = "CommonForm" + MetadataObjectName[1];
		ElsIf MetadataObjectName[0] = "SettingsStorage" Then
			SettingsStorageNewRow = ExternalViewSettings.Rows.Add();
			SettingsStorageNewRow.Setting = SettingForms.Presentation;
			SettingsStorageNewRow.Picture = PictureLib.Form;
			SettingsStorageNewRow.Keys.Add(SettingForms.Value, "");
			SettingsStorageNewRow.RowType = "SettingsStorage" + MetadataObjectName[2];
			SettingsStorageNewRow.Type = "SettingExternalType";
		ElsIf MetadataObjectPresentation[0] = NStr("en='Standard';ru='Стандартные'") Then
			
			// Group of the setting tree
			If CurrentObject <> MetadataObjectPresentation[0] Then
				MetadataObjectNewRow = ExternalViewSettings.Rows.Add();
				MetadataObjectNewRow.Setting = MetadataObjectPresentation[0];
				MetadataObjectNewRow.Picture = SettingForms.Picture;
				MetadataObjectNewRow.RowType = "Object" + MetadataObjectName[1];
				MetadataObjectNewRow.Type = "SettingExternalType";
			EndIf;
			
			// Item of the setting tree
			NewRowOfExternalTypeForms = MetadataObjectNewRow.Rows.Add();
			NewRowOfExternalTypeForms.Setting = MetadataObjectPresentation[1];
			NewRowOfExternalTypeForms.Picture = PictureLib.Form;
			NewRowOfExternalTypeForms.RowType = MetadataObjectName[1] + MetadataObjectName[2];
			NewRowOfExternalTypeForms.Type = "SettingExternalType";
			NewRowOfExternalTypeForms.Keys.Add(SettingForms.Value, "", SettingForms.Check);
			MetadataObjectNewRow.Keys.Add(SettingForms.Value, "", SettingForms.Check);
			
			CurrentObject = MetadataObjectPresentation[0];
			
		Else
			
			// Group of the setting tree
			If CurrentObject <> MetadataObjectName[1] Then
				MetadataObjectNewRow = ExternalViewSettings.Rows.Add();
				MetadataObjectNewRow.Setting = MetadataObjectPresentation[0];
				MetadataObjectNewRow.Picture = SettingForms.Picture;
				MetadataObjectNewRow.RowType = "Object" + MetadataObjectName[1];
				MetadataObjectNewRow.Type = "SettingExternalType";
			EndIf;
			
			// Item of the setting tree
			If MetadataObjectName.Count() = 3 Then
				FormName = MetadataObjectName[2];
			Else
				FormName = MetadataObjectName[3];
			EndIf;
			
			NewRowOfExternalTypeForms = MetadataObjectNewRow.Rows.Add();
			NewRowOfExternalTypeForms.Setting = MetadataObjectPresentation[1];
			NewRowOfExternalTypeForms.Picture = PictureLib.Form;
			NewRowOfExternalTypeForms.RowType = MetadataObjectName[1] + FormName;
			NewRowOfExternalTypeForms.Type = "SettingExternalType";
			NewRowOfExternalTypeForms.Keys.Add(SettingForms.Value, "", SettingForms.Check);
			MetadataObjectNewRow.Keys.Add(SettingForms.Value, "", SettingForms.Check);
			
			CurrentObject = MetadataObjectName[1];
		EndIf;
		
	EndDo;
	
	AddDesktopAndCommandInterfaceSettings(Form, ExternalViewSettings);
	
	ExternalViewSettings.Rows.Sort("Setting Asc", True);
	DesktopAndCommandInterface = ExternalViewSettings.Rows.Find(NStr("en='Desktop and command interface';ru='Рабочий стол и командный интерфейс'"), "Setting");
	
	If DesktopAndCommandInterface <> Undefined Then
		RowIndex = ExternalViewSettings.Rows.IndexOf(DesktopAndCommandInterface);
		ExternalViewSettings.Rows.Move(RowIndex, -RowIndex);
	EndIf;
	
	Form.ValueToFormAttribute(ExternalViewSettings, "ExternalView");
	
EndProcedure

Procedure FillOtherSettingsList(Form)
	
	Form.OtherSettings.GetItems().Clear();
	OtherSettingsTree = Form.FormAttributeToValue("OtherSettings");
	Settings = SettingsReadingFromStorage(CommonSettingsStorage, Form.InfobaseUser);
	Keys = New ValueList;
	OtherKeys = New ValueList;
	
	// Fill in personal settings.
	For Each Setting IN Settings Do
		Keys.Add(Setting.ObjectKey, Setting.SettingsKey);
	EndDo;
	
	OutputSetting = True;
	If Keys.Count() > 0 Then
		
		If Not IsBlankString(Form.Search) Then
			If Find(Upper(NStr("en='Personal settings';ru='Персональные настройки'")), Upper(Form.Search)) = 0 Then
				OutputSetting = False;
			EndIf;
		EndIf;
		
		If OutputSetting Then
			Setting = NStr("en='Personal settings';ru='Персональные настройки'");
			SettingType = "PersonalSettings";
			Picture = PictureLib.UserState02;
			AddLineTree(OtherSettingsTree, Setting, Picture, Keys, SettingType);
		EndIf;
		
	EndIf;
	
	// Fillng of the favorites and printing settings.
	Settings = SettingsReadingFromStorage(SystemSettingsStorage, Form.InfobaseUser);
	
	Keys.Clear();
	IsFavorites = False;
	IsPrintSettings = False;
	KeysEndings = UserSettingsKeys();
	For Each Setting IN Settings Do
		
		SettingName = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Setting.ObjectKey, "/");
		If SettingName.Count() = 1 Then
			Continue;
		EndIf;
		
		If KeysEndings.Find(SettingName[1]) <> Undefined Then
			OtherKeys.Add(Setting.ObjectKey, "Other");
		EndIf;
		
		If SettingName[1] = "UserWorkFavorites" Then
			IsFavorites = True;
		ElsIf SettingName[1] = "SpreadsheetDocumentPrintSettings" Then
			Keys.Add(Setting.ObjectKey, "Other");
			IsPrintSettings = True;
		EndIf;
		
	EndDo;
	
	// Addition of the tree string "Printing settings".
	OutputSetting = True;
	If Not IsBlankString(Form.Search) Then
		
		If Find(Upper(NStr("en='Tabular documents print settings';ru='Настройки печати табличных документов'")), Upper(Form.Search)) = 0 Then
			OutputSetting = False;
		EndIf;
		
	EndIf;
	
	If IsPrintSettings
		AND OutputSetting Then
		Setting = NStr("en='Tabular documents print settings';ru='Настройки печати табличных документов'");
		Picture = PictureLib.Print;
		SettingType = "OtherSetting";
		AddLineTree(OtherSettingsTree, Setting, Picture, Keys, SettingType);
	EndIf;
	
	// Addition of the tree string "Favorite".
	OutputSetting = True;
	If Not IsBlankString(Form.Search) Then
		
		If Find(Upper(NStr("en='Favorites';ru='Избранное'")), Upper(Form.Search)) = 0 Then
			OutputSetting = False;
		EndIf;
		
	EndIf;
	
	If IsFavorites
		AND OutputSetting Then
		
		Setting = NStr("en='Favorites';ru='Избранное'");
		Picture = PictureLib.AddToFavorites;
		Keys.Clear();
		Keys.Add("Common/FavoriteUserWorks", "Other");
		SettingType = "OtherSetting";
		AddLineTree(OtherSettingsTree, Setting, Picture, Keys, SettingType);
		
	EndIf;
	
	// Adding other settings covered by configuration.
	OtherSettings = New Structure;
	UserInfo = New Structure;
	UserInfo.Insert("UserRef", Form.UserRef);
	UserInfo.Insert("InfobaseUserName", Form.InfobaseUser);
	
	UsersService.OnReceiveOtherSettings(UserInfo, OtherSettings);
	Keys = New ValueList;
	
	If OtherSettings <> Undefined Then
		
		For Each OtherSetting IN OtherSettings Do
			
			Result = OtherSetting.Value;
			If Result.SettingsList.Count() <> 0 Then
				
				OutputSetting = True;
				If Not IsBlankString(Form.Search) Then
					
					If Find(Upper(Result.SettingName), Upper(Form.Search)) = 0 Then
						OutputSetting = False;
					EndIf;
					
				EndIf;
				
				If OutputSetting Then
					
					If OtherSetting.Key = "QuickAccessSetup" Then
						For Each Item IN Result.SettingsList Do
							SettingValue = Item[0];
							SettingID = Item[1];
							Keys.Add(SettingValue, SettingID);
						EndDo;
					Else
						Keys = Result.SettingsList.Copy();
					EndIf;
					
					Setting = Result.SettingName;
					If Result.SettingPicture = "" Then
						Picture = PictureLib.OtherUserSettings;
					Else
						Picture = Result.SettingPicture;
					EndIf;
					Type = "OtherUserSetting";
					SettingType = OtherSetting.Key;
					AddLineTree(OtherSettingsTree, Setting, Picture, Keys, Type, SettingType);
					Keys.Clear();
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Other settings that were not included in other sections.
	OutputSetting = True;
	If Not IsBlankString(Form.Search) Then
		
		If Find(Upper(NStr("en='Other settings';ru='Прочие настройки'")), Upper(Form.Search)) = 0 Then
			OutputSetting = False;
		EndIf;
		
	EndIf;
	
	If OtherKeys.Count() <> 0
		AND OutputSetting Then
		Setting = NStr("en='Other settings';ru='Прочие настройки'");
		Picture = PictureLib.OtherUserSettings;
		SettingType = "OtherSetting";
		AddLineTree(OtherSettingsTree, Setting, Picture, OtherKeys, SettingType);
	EndIf;
	
	Form.ValueToFormAttribute(OtherSettingsTree, "OtherSettings");
	
EndProcedure

Procedure AddLineTree(ValueTree, Setting, Picture, Keys, Type = "", RowType = "")
	
	NewRow = ValueTree.Rows.Add();
	NewRow.Setting = Setting;
	NewRow.Picture = Picture;
	NewRow.Type = Type;
	NewRow.RowType = ?(RowType <> "", RowType, Type);
	NewRow.Keys = Keys.Copy();
	
EndProcedure

#EndRegion

#EndIf