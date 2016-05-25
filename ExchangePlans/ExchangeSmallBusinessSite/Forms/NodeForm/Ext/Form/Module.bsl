
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
Procedure RunActionsOnCreateAtServer()
	
	If GetFunctionalOption("WorkInLocalMode") Then
		Items.GroupImportSiteHorizontally.Visible = True;
	Else
		Items.GroupImportSiteHorizontally.Visible = False;
		If Not Object.ExportToSite Then
			Object.ExportToSite = True;
			Modified = True;
		EndIf;
	EndIf;
	
	If Object.ExportToSite Then
		Items.ExchangeTypePages.CurrentPage = Items.DumpToSitePage;
	Else
		Items.ExchangeTypePages.CurrentPage = Items.DumpToCatalogPage;
		RadioButtonExchangePurpose = 1;
	EndIf;
	
	SetLabelExchangeScheduleServer();
	
	PriceKindsFillListServer();
	
	FillDirectoriesTableServer();
	
	SetParametersDirectoriesTableServer();
	
	SetDirectoriesTableGroupListValueTypesServer();
	
	SetElementsVisibleAndEnabled();
	
EndProcedure

&AtServer
Procedure SetElementsVisibleAndEnabled()
	
	Items.PageProductsExport.Visible = Object.ProductsExchange;
	Items.OrdersExchangePage.Visible = Object.OrdersExchange;
	
	Items.ImportFile.Enabled = Object.OrdersExchange;
	
	If Not DataSeparationEnabled Then
		Items.PageAutoExchangeGroup.CurrentPage = Items.AutoExchangePage1Group;
		Items.ConfigureExchangeSchedule.Enabled = Object.UseScheduledJobs;
	Else
		Items.PageAutoExchangeGroup.CurrentPage = Items.AutoExchangePage2Group;
		Items.SiteEchangeInterval.Enabled = Object.UseScheduledJobs;
	EndIf;
	
	If Object.CounterpartiesIdentificationMethod = Enums.CounterpartiesIdentificationMethods.PredefinedValue Then
		Items.CounterpartyToSubstituteIntoOrders.Visible = True;
		Items.GroupForNewCounterparties.Enabled = False;
	Else
		Items.CounterpartyToSubstituteIntoOrders.Visible = False;
		Items.GroupForNewCounterparties.Enabled = True;
	EndIf;
	
	If Not Constants.UseCustomerOrderStates.Get() Then
		Items.StatusesCorrespondenceGroup.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetDirectoriesTableGroupListValueTypesServer()
	
	ValuesType = New TypeDescription("CatalogRef.ProductsAndServices");
	
	For Each DirectoriesTableRow IN DirectoriesTable Do
		
		DirectoriesTableRow.Groups.ValueType = ValuesType;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetParametersDirectoriesTableServer()
	
	TableTitle = NStr("en = 'Folders table (correspondence of items groups and folders on site)'");
	ColumnsTitle = NStr("en = 'Products and services groups'");
	ChoiceFoldersAndItems = FoldersAndItems.Folders;
	
	Items.DirectoriesTableGroup.Title = TableTitle;
	Items.DirectoriesTableGroups.Title = ColumnsTitle;
	Items.DirectoriesTableGroups.ChoiceFoldersAndItems = ChoiceFoldersAndItems;
	
EndProcedure

&AtServer
Procedure PriceKindsFillListServer()
	
	PriceKindsListString = "";
	For Each StringOfPriceKinds IN Object.PriceKinds Do 
		
		NewItem = PriceKindsList.Add();
		NewItem.Value = StringOfPriceKinds.PriceKind;
		
		PriceKindsListString = PriceKindsListString + ?(PriceKindsListString = "","","; ") + StringOfPriceKinds.PriceKind.Description;
		
	EndDo;
	
	Items.ChooseProductsAndServicesPriceKinds.Title = PriceKindsListString;
	
EndProcedure

&AtServer
Procedure FillDirectoriesTableServer()
	
	AllListElementsLabel = "(" + NStr("en = 'All'") + ")";
	
	SavedDirectoriesTable = FormAttributeToValue("Object").SavedDirectoriesTable.Get();
	
	If Not TypeOf(SavedDirectoriesTable) = Type("ValueTable") Then
		
		CreateFolderByDefaultServer();
		
	Else
		
		For Each SavedRowOfDirectoriesTable IN SavedDirectoriesTable Do
			
			NewRow = DirectoriesTable.Add();
			
			FillPropertyValues(NewRow, SavedRowOfDirectoriesTable);
			
			CompositionSettingsStorage = SavedRowOfDirectoriesTable.CompositionSettingsStorage.Get();
			NewRow.AddressOfCompositionSettings = PutToTempStorage(CompositionSettingsStorage, UUID);
			
		EndDo;
		
		If DirectoriesTable.Count() = 0 Then
			
			CreateFolderByDefaultServer();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CreateFolderByDefaultServer()
	
	NewRow = DirectoriesTable.Add();
	NewRow.Directory = NStr("en = 'Main products directory'");
	NewRow.Groups.Add(UNDEFINED, AllListElementsLabel);
	NewRow.DirectoryId = String(New UUID);
	
EndProcedure 

&AtServer
Function CheckExchangeNodeThisDBServer()
	
	ThisNode = ExchangePlans.ExchangeSmallBusinessSite.ThisNode();
	Return Object.Ref = ThisNode;
	
EndFunction

&AtServerNoContext
Procedure ProcessSelectedGroupsServerNoContext(GroupList, AllListElementsLabel)
	
	GroupsSelected = False;
	
	// Delete not the products and services groups.
	
	ArrayDelete = New Array;
	
	For Each ItemOP IN GroupList Do
		
		CurGroup = ItemOP.Value;
		
		If Not ValueIsFilled(CurGroup) OR Not CurGroup.IsFolder Then
			
			ArrayDelete.Add(ItemOP);
			
		EndIf;
		
	EndDo;
	
	For Each ItemDA IN ArrayDelete Do
		
		GroupList.Delete(ItemDA);
		
	EndDo;
	
	// Delete duplicates and subordinate items.
	
	ArrayDelete = New Array;
	
	For Each ItemOP IN GroupList Do
		
		If Not ArrayDelete.Find(ItemOP) = UNDEFINED Then
			
			Continue;
			
		EndIf;
		
		CurGroup = ItemOP.Value;
		
		For Each ItemOPIncl IN GroupList Do

			If Not ArrayDelete.Find(ItemOPIncl) = UNDEFINED Then
			
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
	
	For Each ItemOP IN GroupList Do
		
		If ValueIsFilled(ItemOP.Value) Then
			
			GroupsSelected = True;
			Break;
			
		EndIf;
		
	EndDo;
	
	If Not GroupsSelected Then
		
		GroupList.Clear();
		GroupList.Add(UNDEFINED, AllListElementsLabel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetExchangeOrdersFieldsEnabled()
	
	Items.ImportFile.Enabled = Object.OrdersExchange;
	
EndProcedure

&AtClient
Procedure OnChangeProductsExchange()
	
	SetVisibleOfFormPage();
	
EndProcedure

&AtClient
Procedure OnChangeOrdersExchange()
	
	SetVisibleOfFormPage();
	SetExchangeOrdersFieldsEnabled();
	
EndProcedure

&AtClient
Procedure OnChangeCounterpartiesIdentificationMethod()
	
	IdentificationMethod = PredefinedValue("Enum.CounterpartiesIdentificationMethods.PredefinedValue");
	
	If Object.CounterpartiesIdentificationMethod = IdentificationMethod Then
		
		If Not Items.CounterpartyToSubstituteIntoOrders.Visible Then
			Items.CounterpartyToSubstituteIntoOrders.Visible = True;
			Items.GroupForNewCounterparties.Enabled = False;
		EndIf;
		
	Else
		
		If Items.CounterpartyToSubstituteIntoOrders.Visible Then
			Items.CounterpartyToSubstituteIntoOrders.Visible = False;
			Items.GroupForNewCounterparties.Enabled = True;
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
Procedure OnChangeRadioButtonExchangePurpose()
	
	Object.ExportToSite = RadioButtonExchangePurpose = 0;
	SetVisibleOfExchangeTypePages();
	Modified = True;
	
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
		
		JobSchedule = Schedule;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetLabelExchangeSchedule()
	
	If Not DataSeparationEnabled Then
		
		If JobSchedule = Undefined Then
			HeaderText = NStr("en='Set the schedule of exchange'");
		Else
			HeaderText = JobSchedule;
		EndIf;
		
		Items.ConfigureExchangeSchedule.Title = HeaderText;
		
	Else
		
		If JobSchedule = Undefined Then
			
			SiteEchangeInterval = "Once every 30 minutes"; 
			
		Else
			
			PeriodValue = JobSchedule.RepeatPeriodInDay;
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
Procedure OnChangeUseScheduledJobs()
	
	SetEnabledOfExchangeSchedule();
	
	If Object.UseScheduledJobs Then
		
		If Not DataSeparationEnabled Then
			RunSetupOfExchangeSchedule();
		Else
			SetJobSchedule();
		EndIf;
		
		SetLabelExchangeSchedule();
	EndIf;
	
EndProcedure

&AtClient
Procedure SetEnabledOfExchangeSchedule()
	
	If Not DataSeparationEnabled Then
		Items.ConfigureExchangeSchedule.Enabled = Object.UseScheduledJobs;
	Else
		Items.SiteEchangeInterval.Enabled = Object.UseScheduledJobs;
	EndIf;
	
EndProcedure

&AtClient
Procedure RunSetupOfExchangeSchedule()
	
	If JobSchedule = Undefined Then
		JobSchedule = New JobSchedule;
	EndIf;
	
	Dialog = New ScheduledJobDialog(JobSchedule);
	
	NotifyDescription = New NotifyDescription("ExecuteExchangeScheduleSettingEnd", ThisObject);
	Dialog.Show(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure ExecuteExchangeScheduleSettingEnd(Schedule, AdditionalParameters) Export

	JobSchedule = Schedule;

EndProcedure

&AtClient
Procedure OnStartEditDirectoriesTable(Item, Copy)
	
	If Copy Then
		
		Item.CurrentData.DirectoryId = "";
		
	EndIf;
	
	If (Item.CurrentData.Groups.Count() = 1
		AND Not ValueIsFilled(Item.CurrentData.Groups[0].Value))
		OR Item.CurrentData.Groups.Count() = 0 Then
			
		NewListOfGroups = New ValueList;
		
		ValuesType = New TypeDescription("CatalogRef.ProductsAndServices");
		
		NewListOfGroups.ValueType = ValuesType;
		NewListOfGroups.Add(Undefined, AllListElementsLabel);
		Item.CurrentData.Groups = NewListOfGroups;
			
	EndIf;
	
EndProcedure

&AtClient
Procedure DirectoriesTableGroupsStartChoice(Item, ChoiceData, StandardProcessing)
	
	Groups = Items.DirectoriesTable.CurrentData.Groups;
	
	If Groups.Count() = 1 Then
		
		If Not ValueIsFilled(Groups[0].Value) Then
			
			Groups.Clear();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenFolderFilterForm(AddressOfCompositionSettings)
	
	FormParameters = New Structure();
	FormParameters.Insert("AddressOfCompositionSettings", AddressOfCompositionSettings);
	
	NotifyDescription = New NotifyDescription("OpenDirectoryFilterFormEnd", ThisObject);
	
	OpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	OpenForm("ExchangePlan.ExchangeSmallBusinessSite.Form.FilterSettingForm", FormParameters, ThisForm,,,,NotifyDescription, OpeningMode);
	
EndProcedure

&AtClient
Procedure OpenDirectoryFilterFormEnd(CompositionSettings, AdditionalParameters) Export

	If CompositionSettings = Undefined Then
		Return;
	EndIf;
	
	Modified = True;
	AddressOfCompositionSettings = PutToTempStorage(CompositionSettings, UUID);
	
	Items.DirectoriesTable.CurrentData.AddressOfCompositionSettings = AddressOfCompositionSettings;

EndProcedure // OpenDirectoryFilterForm()

&AtClient
Procedure ChooseProductsAndServicesPriceKinds(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("PriceKindsList", PriceKindsList);
	
	Result = Undefined;

	
	OpenForm("DataProcessor.DataExchangeWithSiteCreationAssistant.Form.PricesKindsChoiceForm",FormParameters,ThisForm,,,, New NotifyDescription("ChooseProductsAndServicesPriceKindsCompletion", ThisObject));
	
EndProcedure

&AtClient
Procedure ChooseProductsAndServicesPriceKindsCompletion(Result1, AdditionalParameters) Export
    
    Result = Result1;
    
    If Result <> Undefined Then
        
        PriceKindsList = Result;
        
        PriceKindsListString = "";
        For Each ItemOP IN PriceKindsList Do
            
            PriceKindsListString = PriceKindsListString + ?(PriceKindsListString = "","","; ") + ItemOP.Presentation;
            
        EndDo;
        
        Items.ChooseProductsAndServicesPriceKinds.Title = PriceKindsListString;
        
        Modified = True;
        
    EndIf;

EndProcedure

&AtClient
Function CheckStatusDoubling(ColumnName)
	
	OrderStatusOnSite = Items.OrdersStatesCorrespondence.CurrentData.OrderStatusOnSite;
	CustomerOrderStatus = Items.OrdersStatesCorrespondence.CurrentData.CustomerOrderStatus;
	
	If Not IsBlankString(OrderStatusOnSite) Then
		Found = Object.OrdersStatesCorrespondence.FindRows(New Structure("OrderStatusOnSite", OrderStatusOnSite));
		If Found.Count() > 1 Then
			ColumnName = "OrderStatusOnSite";
			Return False;
		EndIf;
	EndIf;
	
	If ValueIsFilled(CustomerOrderStatus) Then
		Found = Object.OrdersStatesCorrespondence.FindRows(New Structure("CustomerOrderStatus", CustomerOrderStatus));
		If Found.Count() > 1 Then
			ColumnName = "CustomerOrderStatus";
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

&AtClient
Function CheckIDuniqueness()
	
	DirectoryId = Items.DirectoriesTable.CurrentData.DirectoryId;
	Found = DirectoriesTable.FindRows(New Structure("DirectoryId", DirectoryId));
	IDsAreUnique = Found.Count() = 1;
	
	If Not IDsAreUnique Then
		
		ClearMessages();
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Directory ID should be unique!'"),
			Object.Ref,
			CommonUseClientServer.PathToTabularSection(
				"DirectoriesTable", DirectoriesTable.IndexOf(Items.DirectoriesTable.CurrentData) + 1, "DirectoryId"));
	
	EndIf;
	
	Return IDsAreUnique;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

&AtServer
Procedure SetLabelExchangeScheduleServer()
	
	If Not DataSeparationEnabled Then
		
		If JobSchedule = Undefined Then
			HeaderText = NStr("en='Set the schedule of exchange'");
		Else
			HeaderText = JobSchedule;
		EndIf;
		
		Items.ConfigureExchangeSchedule.Title = HeaderText;
		
	Else
		
		If JobSchedule = Undefined Then
			
			SiteEchangeInterval = "Once every 30 minutes"; 
			
		Else
			
			PeriodValue = JobSchedule.RepeatPeriodInDay;
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
Procedure SetVisibleOfExchangeTypePages()
	
	If Object.ExportToSite Then
		Items.ExchangeTypePages.CurrentPage = Items.DumpToSitePage;
	Else
		Items.ExchangeTypePages.CurrentPage = Items.DumpToCatalogPage;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVisibleOfFormPage()
	
	Items.PageProductsExport.Visible = Object.ProductsExchange;
	Items.OrdersExchangePage.Visible = Object.OrdersExchange;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	Task = ExchangeWithSiteScheduledJobs.FindJob(Object.ScheduledJobID);
	
	If Not Task = Undefined Then
		
		If TypeOf(Task.Schedule) = Type("JobSchedule") Then
			JobSchedule = Task.Schedule;
		ElsIf TypeOf(Task.Schedule) = Type("ValueStorage") Then
			JobSchedule = Task.Schedule.Get();
		Else
			JobSchedule = Undefined;
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ExchangeNodeThisDB = CheckExchangeNodeThisDBServer();
	
	If ExchangeNodeThisDB Then
		Return;
	EndIf;
	
	RunActionsOnCreateAtServer();
	
	DataSeparationEnabled = CommonUseReUse.DataSeparationEnabled();
	
EndProcedure

// Procedure - event handler BeforeWriteAtServer.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If CurrentObject.UseScheduledJobs
		AND (JobSchedule = Undefined
		OR (DataSeparationEnabled AND Not JobSchedule.RepeatPeriodInDay > 0)) Then
		
		CurrentObject.UseScheduledJobs = False;
	EndIf;
	
	Task = ExchangeWithSiteScheduledJobs.FindJob(CurrentObject.ScheduledJobID);
	If CurrentObject.UseScheduledJobs Then
		
		If Task = Undefined Then
			JobID = ExchangeWithSiteScheduledJobs.CreateNewJob(CurrentObject.Code, CurrentObject.Description, JobSchedule);
			CurrentObject.ScheduledJobID = JobID;
		Else
			ExchangeWithSiteScheduledJobs.SetJobParameters(Task, True, CurrentObject.Code, CurrentObject.Description, JobSchedule);
		EndIf;
		
	Else
		
		If Task <> Undefined Then
			ExchangeWithSiteScheduledJobs.DeleteJob(Task);
		EndIf;
		CurrentObject.ScheduledJobID = Undefined;
		
	EndIf;
	
	// Save price kinds.
	
	PriceKinds = CurrentObject.PriceKinds;
	PriceKinds.Clear();
	
	For Each ItemOP IN PriceKindsList Do 
		
		NewRow = PriceKinds.Add();
		NewRow.PriceKind = ItemOP.Value;
		
	EndDo;
	
	// Directories table.
	
	DirectoriesTableTV = FormDataToValue(DirectoriesTable, Type("ValueTable"));
	DirectoriesTableTV.Columns.Add("CompositionSettingsStorage", New TypeDescription("ValueStorage"));
	
	For Each DirectoriesTableRow IN DirectoriesTableTV Do
		
		If Not IsTempStorageURL(DirectoriesTableRow.AddressOfCompositionSettings) Then
			
			Continue;
			
		EndIf;
		
		CompositionSettings = GetFromTempStorage(DirectoriesTableRow.AddressOfCompositionSettings);
		DirectoriesTableRow.CompositionSettingsStorage = New ValueStorage(CompositionSettings);
		
	EndDo;
	
	DirectoriesTableTV.Columns.Delete("AddressOfCompositionSettings");
	
	CurrentObject.SavedDirectoriesTable = New ValueStorage(DirectoriesTableTV);
	CurrentObject.PerformFullExportingCompulsorily = CurrentObject.IsNew();
	
EndProcedure

// Procedure - handler of the AfterWriteAtServer event.
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ExchangeWithSite.UpdateSessionParameters();
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)

	If ExchangeNodeThisDB Then
		
		ClearMessages();
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'The node corresponds to this infobase and can not be used in exchange with website. Use another exchange node or create the new one.'"));
			
		Cancel = True;
		Return;
		
	EndIf;
	
EndProcedure

// Procedure - BeforeWrite event handler.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Object.ProductsExchange AND DirectoriesTable.Count() = 0 Then
		
		Cancel = True;
		
		Message = NStr("en = 'The directories table is not filled!'");
		Field = "DirectoriesTable";
		
		CommonUseClientServer.MessageToUser(Message, Object.Ref, Field);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - command handler CommandCheckConnection.
//
&AtClient
Procedure CommandCheckConnection(Command)
	
	If Modified Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("CommandCheckConnectionEnd", ThisObject), 
			NStr("en = 'Exchange setting is changed and not written. Record?'"),
			QuestionDialogMode.YesNo);
        Return;
		
	EndIf;
	
	CommandCheckConnectionFragment();
EndProcedure

&AtClient
Procedure CommandCheckConnectionEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Not Response = DialogReturnCode.Yes Then
        Return;
    EndIf;
    
    If Not Write() Then
        Return;
    EndIf;
    
    
    CommandCheckConnectionFragment();

EndProcedure

&AtClient
Procedure CommandCheckConnectionFragment()
    
    Var WarningText;
    
    WarningText = "";
    ExchangeWithSite.PerformTestConnectionToSite(Object.Ref, WarningText);
    
    ShowMessageBox(Undefined,WarningText);

EndProcedure

// Procedure - command handler ConfigureExchangeSchedule.
//
&AtClient
Procedure ConfigureExchangeSchedule(Command)
	
	RunSetupOfExchangeSchedule();
	SetLabelExchangeSchedule();
	Modified = True;
	
EndProcedure

// Procedure - command handler SetFilter.
//
&AtClient
Procedure FilterSetup(Command)
	
	If Items.DirectoriesTable.CurrentData = UNDEFINED Then
		Return;
	EndIf;
	
	OpenFolderFilterForm(Items.DirectoriesTable.CurrentData.AddressOfCompositionSettings);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - event handler BeforeEditEnd of the DirectoryTable table.
//
&AtClient
Procedure OrdersStatesCorrespondenceBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)
	
	If CancelEdit Then
		Return;
	EndIf;
	
	ColumnName = "";
	If Not CheckStatusDoubling(ColumnName) Then
		Cancel = True;
		CommonUseClientServer.MessageToUser(
			NStr("en = 'The same status is specified in another table row!'"),
			Object.Ref,
			CommonUseClientServer.PathToTabularSection(
				"Object.OrdersStatesCorrespondence", Object.OrdersStatesCorrespondence.IndexOf(Items.OrdersStatesCorrespondence.CurrentData) + 1, ColumnName));
	EndIf;
	
EndProcedure

// Procedure - event handler SelectionStart of the ExportDirectory input field.
//
&AtClient
Procedure ExportDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	BeginAttachingFileSystemExtension(New NotifyDescription("ExportDirectoryStartChoiceEnd1", ThisObject));
	
EndProcedure

&AtClient
Procedure ExportDirectoryStartChoiceEnd1(Attached, AdditionalParameters) Export
    
    If Not Attached Then
        ShowMessageBox(Undefined,NStr("en = 'The extension to work with files is required for this operation.'"));
        Return;
    EndIf;
    
    Dialog = New FileDialog(FileDialogMode.ChooseDirectory);
    
    Dialog.Title = NStr("en = 'Specify exchange directory'");
    Dialog.Directory = Object.ExportDirectory;
    
    Dialog.Show(New NotifyDescription("ExportDirectoryStartChoiceEnd", ThisObject, New Structure("Dialog", Dialog)));

EndProcedure

&AtClient
Procedure ExportDirectoryStartChoiceEnd(SelectedFiles, AdditionalParameters) Export
    
    Dialog = AdditionalParameters.Dialog;
    
    If (SelectedFiles <> Undefined) Then
        Object.ExportDirectory = Dialog.Directory;
    EndIf;

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

// Procedure - event handler StartChoice input field ImportFile.
//
&AtClient
Procedure ImportFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	BeginAttachingFileSystemExtension(New NotifyDescription("ImportFileStartChoiceEnd1", ThisObject));
	
EndProcedure

&AtClient
Procedure ImportFileStartChoiceEnd1(Attached, AdditionalParameters) Export
    
    If Not Attached Then
        
        ShowMessageBox(Undefined,NStr("en = 'The extension to work with files is required for this operation.'"));
        Return;
        
    EndIf;
    
    Dialog = New FileDialog(FileDialogMode.Open);
    
    Dialog.Title = NStr("en = 'Choose xml-file with orders'");
    Dialog.FullFileName = Object.ImportFile;
    Dialog.Filter = NStr("en = 'XML Document'") + " (*.xml)|*.xml";
    
    Dialog.Show(New NotifyDescription("ImportFileStartChoiceEnd", ThisObject, New Structure("Dialog", Dialog)));

EndProcedure

&AtClient
Procedure ImportFileStartChoiceEnd(SelectedFiles, AdditionalParameters) Export
    
    Dialog = AdditionalParameters.Dialog;
    
    If (SelectedFiles <> Undefined) Then
        
        Object.ImportFile = Dialog.FullFileName;
        
    EndIf;

EndProcedure

// Procedure - event handler Open input field ImportFile.
//
&AtClient
Procedure ImportFileOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	FullFileName = Object.ImportFile;
	If IsBlankString(FullFileName) Then
		Return;
	EndIf;
	
	BeginRunningApplication(Undefined, "explorer.exe /select, " + FullFileName);
	
EndProcedure

// Procedure - event handler StartChoice input field Comment.
//
&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonUseClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Comment");
	
EndProcedure

// Procedure - event handler BeforeEditEnd of the DirectoryTable table.
//
&AtClient
Procedure DirectoriesTableBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)
	
	Cancel = Not CheckIDuniqueness();
	
EndProcedure

// Procedure - event handler OnEditEnd of the DirectoryTable table.
//
&AtClient
Procedure DirectoriesTableOnEditEnd(Item, NewRow, CancelEdit)
	
	If CancelEdit Then
		Return;
	EndIf;
	
	If Item.CurrentData = UNDEFINED Then
		Return;
	EndIf;
	
	ProcessSelectedGroupsServerNoContext(Item.CurrentData.Groups, AllListElementsLabel);
	
	If IsBlankString(Item.CurrentData.DirectoryId) Then
		Item.CurrentData.DirectoryId = String(New UUID);
	EndIf;
	
	If IsBlankString(Item.CurrentData.Directory) Then
		Item.CurrentData.Directory = NStr("en = 'Products directory'") + " " + Upper(TrimAll(Left(Item.CurrentData.DirectoryId, 8)));
	EndIf;
	
	Modified = True;
	
EndProcedure

// Procedure - event handler AfterDelete of the DirectoryTable table.
//
&AtClient
Procedure DirectoriesTableAfterDeleteRow(Item)
	
	Modified = True;
	
EndProcedure

// Procedure - event handler OnStartEdit of the DirectoryTable table.
//
&AtClient
Procedure DirectoriesTableOnStartEdit(Item, NewRow, Copy)
	
	OnStartEditDirectoriesTable(Item, Copy);
	
EndProcedure

// Procedure - event handler OnChange of the RadioButtonExchangePurpose radio button field.
//
&AtClient
Procedure RadioButtonExchangePurposeOnChange(Item)
	
	OnChangeRadioButtonExchangePurpose();
	
EndProcedure

// Procedure - event handler OnChange of the UseScheduledJobs check box field.
//
&AtClient
Procedure UseScheduledJobsOnChange(Item)
	
	OnChangeUseScheduledJobs();
	
EndProcedure

&AtClient
Procedure SiteEchangeIntervalOnChange(Item)
	
	SetJobSchedule();
	SetLabelExchangeSchedule();
	
EndProcedure

// Procedure - event handler OnChange of the ProductExchange checkbox field.
//
&AtClient
Procedure ProductsExchangeOnChange(Item)
	
	OnChangeProductsExchange();
	
EndProcedure

// Procedure - event handler OnChange of the OrderExchange checkbox field.
//
&AtClient
Procedure OrdersExchangeOnChange(Item)
	
	OnChangeOrdersExchange();
	
EndProcedure

// Procedure - event handler OnChange of the CounterpartiesIdentificationMethod input field.
//
&AtClient
Procedure CounterpartyIdentificationMethodOnChange(Item)
	
	OnChangeCounterpartiesIdentificationMethod();
	
EndProcedure








// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
