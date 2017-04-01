////////////////////////////////////////////////////////////////////////////////
// MODULE VARIABLES

&AtClient
Var CurrentPageNumber;

&AtClient
Var AssistantPages;

&AtClient
Var ButtonsAssistant;

&AtClient
Var ForceCloseForm;

&AtClient
Var EmptySchedulePresentation;

&AtClient
Var SettingsComposerInitialized;

&AtClient
Var DoNotCreateCounterpartiesOnOrderImporting;

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
Procedure InitializeComposerServer()
	
	ProductsExportScheme = ExchangePlans.ExchangeSmallBusinessSite.GetTemplate("ProductsExportScheme");
	
	SchemaURL = PutToTempStorage(ProductsExportScheme, UUID);
	
	Object.DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
	Object.DataCompositionSettingsComposer.LoadSettings(ProductsExportScheme.DefaultSettings);
	
EndProcedure

&AtClient
Procedure OnChangeRadioButtonExchangePurpose()
	
	SetVisibleOfExchangeTypesSettings();
	
EndProcedure

&AtClient
Procedure SetVisibleOfExchangeTypesSettings()
	
	If RadioButtonExchangePurpose = 0 Then
		
		Object.ExportToSite = True;
		
		Items.ConnectionSettingsGroup.Enabled = True;
		Items.GroupChoiceOfDirectoriesOnDisc.Enabled = False;
		Items.PagesInformationAboutExchangeThroughWebService.Enabled = False;
		
		Items.ButtonsAssistant.CurrentPage = ButtonsAssistant[2];
		
	ElsIf RadioButtonExchangePurpose = 1 Then
		
		Object.ExportToSite = False;
		
		Items.ConnectionSettingsGroup.Enabled = False;
		Items.GroupChoiceOfDirectoriesOnDisc.Enabled = True;
		Items.PagesInformationAboutExchangeThroughWebService.Enabled = False;
		
		If Object.OrdersExchange Then
			Items.ImportingDirectory.Enabled = True;
		Else
			Items.ImportingDirectory.Enabled = False;
		EndIf;
		
		Items.ButtonsAssistant.CurrentPage = ButtonsAssistant[2];
		
	Else
		
		Object.ExportToSite = False;
		
		Items.ConnectionSettingsGroup.Enabled = False;
		Items.GroupChoiceOfDirectoriesOnDisc.Enabled = False;
		Items.PagesInformationAboutExchangeThroughWebService.Enabled = True;
		
		If IsLocalMode Then
			Items.PagesInformationAboutExchangeThroughWebService.CurrentPage = Items.PageExchangeInformationThroughWebServiceLocal;
		Else
			Items.PagesInformationAboutExchangeThroughWebService.CurrentPage = Items.PageExchangeInformationThroughWebServiceSaaS;
			WebServiceAddress = GetWebServiceAddressSaaS();
		EndIf;
		
		Items.PagesInformationAboutExchangeThroughWebService.CurrentPage.Enabled = True;
		Items.ButtonsAssistant.CurrentPage = ButtonsAssistant[5];
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVisibleAtClient()
	
	// set the assistant current page
	Items.AssistantPages.CurrentPage = AssistantPages[CurrentPageNumber];
	
	// set current page of the assistant buttons
	Items.ButtonsAssistant.CurrentPage = ButtonsAssistant[CurrentPageNumber];
	
	If CurrentPageNumber = 2 Then
		
		If Object.ExportToSite Then 
			RadioButtonExchangePurpose = 0;
		Else
			RadioButtonExchangePurpose = 1;
		EndIf;
		
		SetVisibleOfExchangeTypesSettings();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVisibleOfOrdersExchangeSettings()
	
	IdentificationMethod = PredefinedValue("Enum.CounterpartiesIdentificationMethods.PredefinedValue");
	
	If Object.CounterpartiesIdentificationMethod = IdentificationMethod Then
		
		If Not Items.CounterpartyToSubstituteIntoOrders.Enabled Then
			Items.CounterpartyToSubstituteIntoOrders.Enabled = True;
			Items.GroupForNewCounterparties.Enabled = False;
		EndIf;
		
		DoNotCreateCounterpartiesOnOrderImporting = True;
		
	Else
		
		If Items.CounterpartyToSubstituteIntoOrders.Enabled Then
			Items.CounterpartyToSubstituteIntoOrders.Enabled = False;
			Items.GroupForNewCounterparties.Enabled = True;
		EndIf;
		
		DoNotCreateCounterpartiesOnOrderImporting = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangePageNumber(Iterator)
	
	Cancel = False;
	
	// Change the current page number.
	Increment(CurrentPageNumber, Iterator);
	
	// Event handlers on change of the assistant page.
	ExecuteAssistantEventHandlersOnCurrentPageChange(Cancel, Iterator > 0);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Display the assistant new page.
	SetVisibleAtClient();
	
EndProcedure

&AtClient
Procedure ExecuteAssistantEventHandlersOnCurrentPageChange(Cancel, ThisIsPageNumberIncrease)
	
	If ThisIsPageNumberIncrease Then
		
		ExecuteActionsOnTransitionToNextPage(Cancel);
		
	EndIf;
	
	If Cancel Then
		
		Increment(CurrentPageNumber, ?(ThisIsPageNumberIncrease, -1, +1));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AssistantInitializationAtClient()
	
	CurrentPageNumber = 1;
	
	AssistantPages = New Map;
	ButtonsAssistant   = New Map;
	
	// Assistant pages
	
	AssistantPages.Insert(1, Items.AssistantPageStart);
	AssistantPages.Insert(2, Items.AssistantPageMessagesTransportSettings);
	AssistantPages.Insert(3, Items.AssistantPageProductsAndServicesExportSettings);
	AssistantPages.Insert(4, Items.AssistantPageOrdersExchangeSettings);
	AssistantPages.Insert(5, Items.AssistantPagesAutomaticExchangeSettings);
	
	// Assistant buttons
	
	ButtonsAssistant.Insert(1, Items.BeginButtons);
	ButtonsAssistant.Insert(2, Items.ContinuationButtons);
	ButtonsAssistant.Insert(3, Items.ContinuationButtons);
	ButtonsAssistant.Insert(4, Items.ContinuationButtons);
	ButtonsAssistant.Insert(5, Items.EndingButtons);
	
EndProcedure

&AtClient
Procedure ScheduledJobScheduleEdit()
	
	// If the schedule is not initialized in the form on server, then create a new one.
	If Object.JobSchedule = Undefined Then
		
		Object.JobSchedule = New JobSchedule;
		
	EndIf;
	
	Dialog = New ScheduledJobDialog(Object.JobSchedule);
	Notification = New NotifyDescription("ScheduleScheduledJobs1EditCompletion",ThisForm);
	Dialog.Show(Notification);
	
EndProcedure

&AtClient
Procedure ScheduleScheduledJobs1EditCompletion(Result,Parameters) Export
	
	If Result <> Undefined Then
		Object.JobSchedule = Result;
	EndIf;
	
EndProcedure

&AtClient
// Function returns RepeatPeriodInDay in seconds
//
Function GetRepeatPeriodDuringDay()
	
	ValuesOfSelection = SelectValuesToAccordanceSecondsCount();
	
	RepeatPeriodInDay = ValuesOfSelection.Get(SiteEchangeInterval);
	Return ?(RepeatPeriodInDay = Undefined, 1800, RepeatPeriodInDay);
	
EndFunction //GetRepeatPeriodDuringDay()

&AtClient
// Function returns the match of the selection labels ando number of seconds
// 
Function SelectValuesToAccordanceSecondsCount()
	
	MapInscriptions = New Map;
	MapInscriptions.Insert("Once every 5 minutes", 300);
	MapInscriptions.Insert("Once every 15 minutes", 900);
	MapInscriptions.Insert("Once every 30 minutes", 1800);
	MapInscriptions.Insert("Once an hour", 3600);
	MapInscriptions.Insert("Once in 3 hours", 10800);
	MapInscriptions.Insert("Once every 6 hours", 21600);
	MapInscriptions.Insert("Once every 12 hours", 43200);
	
	Return MapInscriptions;
	
EndFunction //SelectValuesToAccordanceSecondsCount()

&AtClient
// Fills the schedule values of the scheduled job.
//
Procedure SetJobSchedule()
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);

	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	RepeatPeriodInDay = GetRepeatPeriodDuringDay();
	
	If RepeatPeriodInDay > 0 Then
		
		Schedule = New JobSchedule;
		Schedule.Months					= Months;
		Schedule.WeekDays				= WeekDays;
		Schedule.RepeatPeriodInDay = RepeatPeriodInDay; // Seconds
		Schedule.DaysRepeatPeriod		= 1; // every day
		
		Object.JobSchedule = Schedule;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshSchedulePresentation()
	
	If Not DataSeparationEnabled Then
		
		SchedulePresentation = String(Object.JobSchedule);
		
		If SchedulePresentation = EmptySchedulePresentation Then
			SchedulePresentation = NStr("en='Schedule not specified';ru='Расписание не задано'");
		EndIf;
		
		Items.ConfigureScheduleJobSchedule.Title = SchedulePresentation;
		
	Else
		
		If Object.JobSchedule = Undefined Then
			
			SiteEchangeInterval = "Once every 30 minutes"; 
			
		Else
			
			PeriodValue = Object.JobSchedule.RepeatPeriodInDay;
			If PeriodValue = 0 Then
				
				SiteEchangeInterval = "Once every 30 minutes";
				
			ElsIf PeriodValue <= 300 Then
				
				SiteEchangeInterval = "Once every 5 minutes";
				
			ElsIf PeriodValue <= 900 Then
				
				SiteEchangeInterval = "Once every 15 minutes";
				
			ElsIf PeriodValue <= 1800 Then
				
				SiteEchangeInterval = "Once every 30 minutes";
				
			ElsIf PeriodValue <= 3600 Then
				
				SiteEchangeInterval = "Once an hour";
				
			ElsIf PeriodValue <= 10800 Then
				
				SiteEchangeInterval = "Once in 3 hours";
				
			ElsIf PeriodValue <= 21600 Then
				
				SiteEchangeInterval = "Once every 6 hours";
				
			ElsIf PeriodValue <= 43200 Then
				
				SiteEchangeInterval = "Once every 12 hours";
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetEnabledOfExchangeSchedule()
	
	If Not DataSeparationEnabled Then
		Items.ConfigureScheduleJobSchedule.Enabled = Object.UseScheduledJobs;
	Else
		Items.SiteEchangeInterval.Enabled = Object.UseScheduledJobs;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChooseDirectory(ExportDirectory = True)
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("ExportDirectory", ExportDirectory);
	
	BeginAttachingFileSystemExtension(New NotifyDescription("ChooseDirectoryEnd1", ThisForm, NotificationParameters));
	
EndProcedure

&AtClient
Procedure ChooseDirectoryEnd1(Attached, AdditionalParameters) Export
    
    If Not Attached Then
        ShowMessageBox(Undefined,NStr("en='The extension to work with files is required for this operation.';ru='Для данной операции необходимо установить расширение работы с файлами!'"));
        Return;
    EndIf;
    
    Dialog = New FileDialog(FileDialogMode.ChooseDirectory);
    
    Dialog.Title = NStr("en='Specify exchange directory';ru='Укажите каталог обмена'");
    Dialog.Directory   = ?(AdditionalParameters.ExportDirectory, Object.ExportDirectory, Object.ImportingDirectory);
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("Dialog", Dialog);
	NotificationParameters.Insert("ExportDirectory", AdditionalParameters.ExportDirectory);
    
    Dialog.Show(New NotifyDescription("ChooseDirectoryEnd", ThisForm, NotificationParameters));

EndProcedure

&AtClient
Procedure ChooseDirectoryEnd(SelectedFiles, AdditionalParameters) Export
    
	Dialog = AdditionalParameters.Dialog;
	
	If (SelectedFiles <> Undefined) Then
		
		If AdditionalParameters.ExportDirectory Then
			Object.ExportDirectory = Dialog.Directory;
		Else
			Object.ImportingDirectory = Dialog.Directory;
		EndIf;
		
	EndIf;
    
EndProcedure

&AtClient
Procedure ExecuteChecksOnClickDone(Cancel)
	
	ClearMessages();
	
	If Object.UseScheduledJobs Then
		
		If Object.JobSchedule = Undefined
			OR String(Object.JobSchedule) = EmptySchedulePresentation Then
			
			Message = NStr("en='Schedule need to be set when using automatic update!';ru='При использовании автоматического обмена расписание должно быть установлено!'");
			CommonUseClientServer.MessageToUser(Message,,,,Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateNewDataExchangeAtClient(Cancel)
	
	Status(NStr("en='Settings of data exchange with website are being created';ru='Выполняется создание настройки обмена данными с web-сайтом'"));
	
	CreateNewDataExchangeAtServer(SettingsComposerInitialized, Cancel);
	
	If Cancel Then
		
		ShowMessageBox(Undefined,NStr("en='Errors occurred during creation of data exchange settings!';ru='При создании настройки обмена данными возникли ошибки!'"));
		
	Else
		
		ShowUserNotification(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='""%1""';ru='""%1""'"), Object.ExchangeNodeRef),,
			NStr("en='New exchange node with WEB - site created successfully!';ru='Новый узел обмена с WEB - сайтом создан успешно!'"),
			PictureLib.Information32);
		
		NotifyWritingNew(Object.ExchangeNodeRef);
		
		If ExecuteDataExchangeNow Then
			
			InitializationOfDataExchangeAtClient();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CreateNewDataExchangeAtServer(SettingsComposerInitialized, Cancel)
	
	// Save prices kinds list.
	
	PriceKinds = Object.PriceKinds;
	PriceKinds.Clear();
	
	For Each ItemOP IN PriceKindsList Do 
		
		NewRow = PriceKinds.Add();
		NewRow.PriceKind = ItemOP.Value;
		
	EndDo;
	
	//Initialize the composer of settings if it was not initialized.
	
	If Not SettingsComposerInitialized Then
		
		ProductsExportScheme = ExchangePlans.ExchangeSmallBusinessSite.GetTemplate("ProductsExportScheme");
		
		SchemaURL = PutToTempStorage(ProductsExportScheme, UUID);
		Object.DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL)); 
		Object.DataCompositionSettingsComposer.LoadSettings(ProductsExportScheme.DefaultSettings);
		
	EndIf;
	
	// Create and save the directories table.
	
	DirectoriesTable = New ValueTable;
	
	DirectoriesTable.Columns.Add("Directory");
	DirectoriesTable.Columns.Add("Groups");
	DirectoriesTable.Columns.Add("DirectoryId");
	DirectoriesTable.Columns.Add("CompositionSettingsStorage");
	
	ProcessSelectedGroupsAtServerNoContext(ListProductsAndServicesGroups);
	
	NewRow = DirectoriesTable.Add();
	NewRow.Directory = NStr("en='Main products directory';ru='Основной каталог товаров'");
	NewRow.Groups = ListProductsAndServicesGroups;
	NewRow.DirectoryId = String(New UUID);
	NewRow.CompositionSettingsStorage = New ValueStorage(Object.DataCompositionSettingsComposer.GetSettings());
	
	Object.SavedDirectoriesTable = New ValueStorage(DirectoriesTable);
	
	DataProcessorObject = FormAttributeToValue("Object");
	DataProcessorObject.RunNewDataExchangeCreationActions(Cancel);
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

&AtServerNoContext
Procedure ProcessSelectedGroupsAtServerNoContext(GroupList)
	
	// Delete duplicates and subordinate items.
	
	ArrayDelete = New Array;
	
	For Each ItemOP IN GroupList Do
		
		If Not ArrayDelete.Find(ItemOP) = Undefined Then
			
			Continue;
			
		EndIf;
		
		CurGroup = ItemOP.Value;
		
		For Each ItemOPIncl IN GroupList Do
			
			If Not ArrayDelete.Find(ItemOPIncl) = Undefined Then
			
				Continue;
			
			EndIf;
			
			If Not ItemOPIncl = ItemOP
				AND ItemOPIncl.Value = CurGroup Then
				
				ArrayDelete.Add(ItemOPIncl);
				
			Else
			
				If ItemOPIncl.Value.BelongsToItem(CurGroup) Then
				
					ArrayDelete.Add(ItemOPIncl);
				
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	For Each ItemDA IN ArrayDelete Do
		
		GroupList.Delete(ItemDA);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure InitializationOfDataExchangeAtClient()
	
	ExchangeNode = Object.ExchangeNodeRef;
	
	Status(
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 started data exchange with site';ru='%1 начат обмен данными с сайтом'"),
			Format(CurrentDate(), "DLF=DT"))
		,,
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='by exchange node ""%1""...';ru='по узлу обмена ""%1""...'"),
			ExchangeNode));
	
	ExchangeWithSite.RunExchange(ExchangeNode, NStr("en='Interactive exchange';ru='Интерактивный обмен'"));
	
	ShowUserNotification(
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 ""%2""';ru='%1 ""%2""'"),
			Format(CurrentDate(), "DLF=DT"),
			ExchangeNode) 
		,,
		NStr("en='Exchange with site completed';ru='Обмен с сайтом завершен'"),
		PictureLib.Information32);
		
	Notify("ExchangeWithSiteSessionFinished");
	
EndProcedure

&AtClient
Function GetProductsAndServicesGroupsListTitle(ListProductsAndServicesGroups)
	
	GroupsListString = "";
	For Each ItemOfList IN ListProductsAndServicesGroups Do
		
		GroupsListString = GroupsListString + ?(GroupsListString = "","","; ") + ItemOfList.Presentation;
		
	EndDo;
	
	Return GroupsListString;
	
EndFunction

&AtServerNoContext
Function GetWebServiceAddressSaaS()
	
	WebServiceAddress = GetInfobaseURL() + "/ws/SiteExchange?wsdl";
	Return WebServiceAddress;
	
EndFunction

// WIZARD PAGE CHANGE EVENT HANDLERS

&AtClient
Procedure ExecuteActionsOnTransitionToNextPage(Cancel)
	
	ClearMessages();
	
	If CurrentPageNumber = 2 Then 
		
		If Not Object.ProductsExchange
			AND Not Object.OrdersExchange Then 
			
			Message = NStr("en='To continue configuration, at least one of data exchange modes should be selected!';ru='Для продолжения настроек должен быть выбран хотя бы один из режимов обмена данными!'");
			CommonUseClientServer.MessageToUser(Message,,,, Cancel);
			
		EndIf;
		
		If IsLocalMode Then
			Items.PagesInformationAboutExchangeThroughWebService.CurrentPage = Items.PageExchangeInformationThroughWebServiceLocal;
		Else
			Items.PagesInformationAboutExchangeThroughWebService.CurrentPage = Items.PageExchangeInformationThroughWebServiceSaaS;
		EndIf;
		
	ElsIf CurrentPageNumber = 3 Then 
		
		If Object.ExportToSite Then 
			
			If IsBlankString(Object.SiteAddress) Then 
				
				Message = NStr("en='Specify site address';ru='Укажите адрес сайта'");
				CommonUseClientServer.MessageToUser(Message,, "Object.SiteAddress",, Cancel);
				
			EndIf;
			
			If IsBlankString(Object.UserName) Then 
				
				Message = NStr("en='Specify user name';ru='Укажите имя пользователя'");
				CommonUseClientServer.MessageToUser(Message,, "Object.UserName",, Cancel);
				
			EndIf;
			
		Else
			
			If IsBlankString(Object.ExportDirectory) Then 
				
				Message = NStr("en='Specify import directory';ru='Укажите каталог выгрузки'");
				CommonUseClientServer.MessageToUser(Message,, "Object.ExportDirectory",, Cancel);
				
			EndIf;
			
			If Object.OrdersExchange AND IsBlankString(Object.ImportingDirectory) Then 
				
				Message = NStr("en='Specify directory for loading';ru='Укажите каталог загрузки'");
				CommonUseClientServer.MessageToUser(Message,, "Object.ImportingDirectory",, Cancel);
				
			EndIf;
			
		EndIf;
		
		If Not SettingsComposerInitialized Then
			InitializeComposerServer();
			SettingsComposerInitialized = True;
		EndIf;
		Items.CompositionSettingsTable.Refresh();
		
	ElsIf CurrentPageNumber = 5 Then 
		
		If Object.OrdersExchange Then
			
			If Not ValueIsFilled(Object.CounterpartiesIdentificationMethod) Then
				
				Message = NStr("en='Specify counterparty identification method';ru='Укажите способ идентификации контрагентов'");
				CommonUseClientServer.MessageToUser(Message,, "Object.CounterpartiesIdentificationMethod",, Cancel);
				
			ElsIf DoNotCreateCounterpartiesOnOrderImporting 
				AND Not ValueIsFilled(Object.CounterpartyToSubstituteIntoOrders) Then
				
				Message = NStr("en='Choose counterparty for placing it into orders';ru='Выберите контрагента для подстановки в заказы'");
				CommonUseClientServer.MessageToUser(Message,, "Object.CounterpartyToSubstituteIntoOrders",, Cancel);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Increment(Number, Val Iterator = 1)
	
	Number = Number + Iterator;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsInRoleAddChangeOfDataExchanges = Users.RolesAvailable("DataSynchronizationSetting");
	
	If Not IsInRoleAddChangeOfDataExchanges Then
		
		DataExchangeServer.ShowMessageAboutError(NStr("en='You have no enough access rights!';ru='Недостаточно прав доступа!'"), Cancel);
		Return;
		
	EndIf;
	
	If Not Parameters.Property("CallPlanOfExchange") Then
		
		Message = NStr("en='You can open the wizard only from the command interface. Assistant work is completed.';ru='Работа помощника поддерживается только при вызове из командного интерфейса! Работа помощника завершена.'");
		DataExchangeServer.ShowMessageAboutError(Message, Cancel);
		
	EndIf;
	
	Object.ProductsExchange     = True;
	Object.OrdersExchange     = True;
	Object.ExportToSite   = True;
	Object.ExportPictures = True;
	
	ExecuteExchangeAfterClosingForms = True;
	
	Object.CounterpartiesIdentificationMethod = Enums.CounterpartiesIdentificationMethods.Description;
	
	If Not GetFunctionalOption("WorkInLocalMode") Then
		Items.GroupSharingDirectoryOnHardDrive.Visible = False;
	EndIf;
	
	Items.CounterpartyToSubstituteIntoOrders.Enabled = False;
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Items.SettingsGroupAutoExchangePages.CurrentPage = Items.SettingsGroupAutoExchangePage1;
		Items.ConfigureScheduleJobSchedule.Enabled = False;
		Items.ConfigureScheduleJobSchedule.Title = NStr("en='Schedule not specified';ru='Расписание не задано'");
	Else
		Items.SettingsGroupAutoExchangePages.CurrentPage = Items.SettingsGroupAutoExchangePage2;
		Items.SiteEchangeInterval.Enabled = False;
		SiteEchangeInterval = "Once every 30 minutes";
	EndIf;
	
	IsLocalMode = GetFunctionalOption("WorkInLocalMode");
	
	DataSeparationEnabled = CommonUseReUse.DataSeparationEnabled();
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	SettingsComposerInitialized = False;
	ForceCloseForm = False;
	DoNotCreateCounterpartiesOnOrderImporting = False;
	
	AssistantInitializationAtClient();
	
	EmptySchedulePresentation = String(New JobSchedule);
	
EndProcedure

// Procedure - event  handler BeforeClose.
//
&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If ForceCloseForm = True Then
		Return;
	EndIf;
	
	Cancel = True;
	NotifyDescription = New NotifyDescription("BeforeCloseEnd", ThisObject);
	ShowQueryBox(NOTifyDescription, NStr("en='Do you want to cancel the setting of data exchange with website and close the assistant?';ru='Отменить настройку обмена данными с web-сайтом и выйти из помощника?'"), QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure BeforeCloseEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		ForceCloseForm = True;
		Close();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM ITEMS EVENTS HANDLERS

// Procedure - event handler OnChange of the RadioButtonExchangePurposeImportToSite radio button field.
//
&AtClient
Procedure RadioButtonExchangePurposeImportToSiteOnChange(Item)
	
	OnChangeRadioButtonExchangePurpose();
	
EndProcedure

// Procedure - event handler OnChange of the RadioButtonExchangePurposeExportToDirectoryAtDisc radio button field.
//
&AtClient
Procedure RadioButtonExchangePurposeExportToDirectoryAtDiscOnChange(Item)
	
	OnChangeRadioButtonExchangePurpose();
	
EndProcedure

// Procedure - event handler OnChange of the SwitchExchangePurposeExchangeThroughWebService radio button field.
//
&AtClient
Procedure SwitchExchangePurposeExchangeThroughWebServiceOnChange(Item)
	
	OnChangeRadioButtonExchangePurpose();
	
EndProcedure

// Procedure - event handler OnChange of the UseAutomaticDataExchange check box.
//
&AtClient
Procedure UseAutomaticDataExchangeOnChange(Item)
	
	SetEnabledOfExchangeSchedule();
	
	If Object.UseScheduledJobs Then
		
		If Not DataSeparationEnabled Then
			ScheduledJobScheduleEdit();
		Else
			SetJobSchedule();
		EndIf;
		
		RefreshSchedulePresentation();
	EndIf;
	
EndProcedure

// Procedure - event handler SelectionStart of the ExportDirectory input field.
//
&AtClient
Procedure ExportDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ChooseDirectory(True);
	
EndProcedure

// Procedure - event handler Open of the ExportDirectory input field.
//
&AtClient
Procedure ExportDirectoryOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	FullFileName = Object.ExportDirectory;
	If IsBlankString(FullFileName) Then
		Return;
	EndIf;
	
	BeginRunningApplication(Undefined, FullFileName);
	
EndProcedure

// Procedure - event handler SelectionStart of the ImportingDirectory input field.
//
&AtClient
Procedure ImportingDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ChooseDirectory(False);
	
EndProcedure

// Procedure - event handler Open of the ImportingDirectory input field.
//
&AtClient
Procedure ImportingDirectoryOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	FullFileName = Object.ImportingDirectory;
	If IsBlankString(FullFileName) Then
		Return;
	EndIf;
	
	BeginRunningApplication(Undefined, FullFileName);
	
EndProcedure

// Procedure - event handler OnChange of the CounterpartiesIdentificationMethod input field.
//
&AtClient
Procedure CounterpartyIdentificationMethodOnChange(Item)
	
	SetVisibleOfOrdersExchangeSettings();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - command handler ChooseProductsAndServicesPriceKinds.
//
&AtClient
Procedure ChooseProductsAndServicesPriceKinds(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("PriceKindsList", PriceKindsList);
	
	Notification = New NotifyDescription("ChooseProductsAndServicesPriceKindsCompletion",ThisForm);
	OpenForm("DataProcessor.DataExchangeWithSiteCreationAssistant.Form.PricesKindsChoiceForm", FormParameters, ThisForm,,,,Notification);
	
EndProcedure

&AtClient
Procedure ChooseProductsAndServicesPriceKindsCompletion(Result,Parameters) Export
	
	If Result <> Undefined Then
		
		PriceKindsList = Result;
		
		PriceKindsListString = "";
		For Each ItemOP IN PriceKindsList Do
			
			PriceKindsListString = PriceKindsListString + ?(PriceKindsListString = "","","; ") + ItemOP.Presentation;
			
		EndDo;
		
		Items.ChooseProductsAndServicesPriceKinds.Title = PriceKindsListString;
		
	EndIf;
	
EndProcedure

// Procedure - command handler ChooseProductsAndServicesGroups.
//
&AtClient
Procedure ChooseProductsAndServicesGroups(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ListProductsAndServicesGroups", ListProductsAndServicesGroups);
	
	Notification = New NotifyDescription("SelectProductsAndServicesFoldersCompletion",ThisForm);
	OpenForm("DataProcessor.DataExchangeWithSiteCreationAssistant.Form.ProductsAndServicesGroupsChoiceForm", FormParameters, ThisForm,,,,Notification);
	
EndProcedure

&AtClient
Procedure SelectProductsAndServicesFoldersCompletion(Result,Parameters) Export
	
	If Result <> Undefined Then
		
		ListProductsAndServicesGroups = Result;
		Items.ChooseProductsAndServicesGroups.Title = GetProductsAndServicesGroupsListTitle(ListProductsAndServicesGroups);
		
	EndIf;
	
EndProcedure

// Procedure - command handler CommandNext.
//
&AtClient
Procedure CommandNext(Command)
	
	If (CurrentPageNumber = 2 AND Not Object.ProductsExchange)
		OR (CurrentPageNumber = 3 AND Not object.OrdersExchange) Then
		
		ChangePageNumber(+2);
		
	Else
		
		ChangePageNumber(+1);
		
	EndIf;
	
EndProcedure

// Procedure - command handler CommandBack.
//
&AtClient
Procedure CommandBack(Command)
	
	If (CurrentPageNumber = 5 AND Not Object.OrdersExchange)
		OR (CurrentPageNumber = 4 AND Not object.ProductsExchange) Then
		
		ChangePageNumber(-2);
		
	Else
		
		ChangePageNumber(-1);
		
	EndIf;
	
EndProcedure

// Procedure - command handler CommandDone.
//
&AtClient
Procedure CommandDone(Command)
	
	If RadioButtonExchangePurpose = 2 Then
		
		ForceCloseForm = True;
		Close();
		
	Else
		
		Cancel = False;
		
		ExecuteChecksOnClickDone(Cancel);
		
		If Not Cancel Then
			
			CreateNewDataExchangeAtClient(Cancel);
			
			ForceCloseForm = True;
			Close();
			
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - command handler CommandCancel.
//
&AtClient
Procedure CommandCancel(Command)
	
	ForceCloseForm = False;
	Close();
	
EndProcedure

// Procedure - command handler CommandCheckConnection.
//
&AtClient
Procedure CommandCheckConnection(Command)
	
	ConnectionSettings = New Structure;
	
	ConnectionSettings.Insert("SiteAddress", Object.SiteAddress);
	ConnectionSettings.Insert("UserName", Object.UserName);
	ConnectionSettings.Insert("Password", Object.Password);
	
	WarningText = "";
	ExchangeWithSite.PerformTestConnectionToSite(ConnectionSettings, WarningText);
	
	ShowMessageBox(Undefined,WarningText);
	
EndProcedure

// Procedure - command handler ConfigureScheduleJobSchedule.
//
&AtClient
Procedure ConfigureScheduleJobSchedule(Command)
	
	ScheduledJobScheduleEdit();
	RefreshSchedulePresentation();
	
EndProcedure

&AtClient
Procedure SiteEchangeIntervalOnChange(Item)
	
	SetJobSchedule();
	RefreshSchedulePresentation();
	
EndProcedure

// Procedure - command handler HowToPublishWebService.
//
&AtClient
Procedure HowToPublishWebService(Command)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Title", "Publication on the web server");
	OpenParameters.Insert("ToolTipKey", "AssistantOfExchangeWithSiteSettings_ExchangeOverWebService");
	OpenForm("DataProcessor.ToolTipManager.Form", OpenParameters);
	
EndProcedure

















