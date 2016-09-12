#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnComposeResult(ResultDocument, DetailsDataObject, StandardProcessing, StorageAddress) 	
	StandardProcessing = False;
	ReportSettings = SettingsComposer.GetSettings();
	Period = ReportSettings.DataParameters.Items.Find("Period").Value;
	ReportVariant = ReportSettings.DataParameters.Items.Find("ReportVariant").Value; 
	If ReportVariant = "EventLogMonitorControl" Then
		FormingResultReport = Reports.EventsLogAnalysis.
			GenerateReportEventLogMonitorControl(Period.StartDate, Period.EndDate);
		// ReportIsEmpty - parameter showing information availability in the report. It is required for mailing of the reports.
		ReportIsEmpty = FormingResultReport.ReportIsEmpty;
		SettingsComposer.Settings.AdditionalProperties.Insert("ReportIsEmpty", ReportIsEmpty);
		ResultDocument.Put(FormingResultReport.Report);
	ElsIf ReportVariant = "GanttChart" Then
		ScheduledJobsWorkDuration(ReportSettings, ResultDocument);
	Else
		ReportParameters = ReportParametersActiveUser(ReportSettings);
		ReportParameters.Insert("StartDate", Period.StartDate);
		ReportParameters.Insert("EndDate", Period.EndDate);
		ReportParameters.Insert("ReportVariant", ReportVariant);
		TemplateComposer = New DataCompositionTemplateComposer;
		CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsDataObject);
		CompositionProcessor = New DataCompositionProcessor;
		CompositionProcessor.Initialize(CompositionTemplate,
			Reports.EventsLogAnalysis.DataFromEventLog(ReportParameters), DetailsDataObject, True);
        OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
		OutputProcessor.SetDocument(ResultDocument);
		OutputProcessor.BeginOutput();
		While True Do
			ResultItem = CompositionProcessor.Next();
			If ResultItem = Undefined Then
				Break;
			Else
				OutputProcessor.OutputItem(ResultItem);
			EndIf;
		EndDo;
		ResultDocument.ShowRowGroupLevel(1);
		OutputProcessor.EndOutput();
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportVariant = ReportSettings.DataParameters.Items.Find("ReportVariant").Value;
	If ReportVariant = "GanttChart" Then
		DayPeriod = ReportSettings.DataParameters.Items.Find("DayPeriod").Value;
		BeginSelection = ReportSettings.DataParameters.Items.Find("BeginSelection");
		EndSelection = ReportSettings.DataParameters.Items.Find("EndSelection");
		
		If Not ValueIsFilled(DayPeriod.Date) Then
			CommonUseClientServer.MessageToUser(
				NStr("en='The Day field value is not filled!';ru='Не заполнено значение поля День!'"), , );
			Cancel = True;
			Return;
		EndIf;
		
		If ValueIsFilled(BeginSelection.Value)
		AND ValueIsFilled(EndSelection.Value)
		AND BeginSelection.Value > EndSelection.Value
		AND BeginSelection.Use 
		AND EndSelection.Use Then
			CommonUseClientServer.MessageToUser(
				NStr("en='Value of the period start must not exceed the end value!';ru='Значение начала периода не может быть больше значения конца!'"), , );
			Cancel = True;
			Return;
		EndIf;
		
	ElsIf ReportVariant = "ActiveUser" Then
		
		User = ReportSettings.DataParameters.Items.Find("User").Value;
		
		If Not ValueIsFilled(User) Then
			CommonUseClientServer.MessageToUser(
				NStr("en='User field value is not filled!';ru='Не заполнено значение поля Пользователь!'"), , );
			Cancel = True;
			Return;
		EndIf;
		
		If Reports.EventsLogAnalysis.IBUserName(User) = Undefined Then
			CommonUseClientServer.MessageToUser(
				NStr("en='Report generation is available only to the user who has the username to log on to the application.';ru='Формирование отчета возможно только для пользователя, которому указано имя для входа в программу.'"), , );
			Cancel = True;
			Return;
		EndIf;
		
	ElsIf ReportVariant = "UsersActivityAnalysis" Then
		
		UsersAndGroups = ReportSettings.DataParameters.Items.Find("UsersAndGroups").Value;
		
		If TypeOf(UsersAndGroups) = Type("CatalogRef.Users") Then
			
			If Reports.EventsLogAnalysis.IBUserName(UsersAndGroups) = Undefined Then
				CommonUseClientServer.MessageToUser(
					NStr("en='Report generation is available only to the user who has the username to log on to the application.';ru='Формирование отчета возможно только для пользователя, которому указано имя для входа в программу.'"), , );
				Cancel = True;
				Return;
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(UsersAndGroups) Then
			CommonUseClientServer.MessageToUser(
				NStr("en='Users field value is not filled!';ru='Не заполнено значение поля Пользователи!'"), , );
			Cancel = True;
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure
 
#EndRegion

#Region ServiceProceduresAndFunctions

Function ReportParametersActiveUser(ReportSettings)
	
	UsersAndGroups = ReportSettings.DataParameters.Items.Find("UsersAndGroups").Value;
	User = ReportSettings.DataParameters.Items.Find("User").Value;
	OutputBusinessProcesses = ReportSettings.DataParameters.Items.Find("OutputBusinessProcesses");
	OutputTasks = ReportSettings.DataParameters.Items.Find("OutputTasks");
	OutputCatalogs = ReportSettings.DataParameters.Items.Find("OutputCatalogs");
	OutputDocuments = ReportSettings.DataParameters.Items.Find("OutputDocuments");
	
	If Not OutputBusinessProcesses.Use Then
		ReportSettings.DataParameters.SetParameterValue("OutputBusinessProcesses", False);
	EndIf;
	If Not OutputTasks.Use Then
		ReportSettings.DataParameters.SetParameterValue("OutputTasks", False);
	EndIf;
	If Not OutputCatalogs.Use Then
		ReportSettings.DataParameters.SetParameterValue("OutputCatalogs", False);
	EndIf;
	If Not OutputDocuments.Use Then
		ReportSettings.DataParameters.SetParameterValue("OutputDocuments", False);
	EndIf;		
	
	ReportParameters = New Structure;
	ReportParameters.Insert("UsersAndGroups", UsersAndGroups);
	ReportParameters.Insert("User", User);
	ReportParameters.Insert("OutputBusinessProcesses", OutputBusinessProcesses.Value);
	ReportParameters.Insert("OutputTasks", OutputTasks.Value);
	ReportParameters.Insert("OutputCatalogs", OutputCatalogs.Value);
	ReportParameters.Insert("OutputDocuments", OutputDocuments.Value);
	
	Return ReportParameters;
EndFunction

Procedure ScheduledJobsWorkDuration(ReportSettings, ResultDocument)
	TitleOutput = ReportSettings.OutputParameters.Items.Find("TitleOutput");
	FilterOutput = ReportSettings.OutputParameters.Items.Find("FilterOutput");
	ReportHeader = ReportSettings.OutputParameters.Items.Find("Title");
	DayPeriod = ReportSettings.DataParameters.Items.Find("DayPeriod").Value;
	BeginSelection = ReportSettings.DataParameters.Items.Find("BeginSelection");
	EndSelection = ReportSettings.DataParameters.Items.Find("EndSelection");
	ScheduledJobsSessionsMinimumLength = ReportSettings.DataParameters.Items.Find(
																"ScheduledJobsSessionsMinimumLength");
	ShowBackgroundJobs = ReportSettings.DataParameters.Items.Find("ShowBackgroundJobs");
	HideSceduledJobs = ReportSettings.DataParameters.Items.Find("HideSceduledJobs");
	SizeConcurrentSessions = ReportSettings.DataParameters.Items.Find("SizeConcurrentSessions");
	
	// Check of selection of the Use check box for the parameters.
	If Not ScheduledJobsSessionsMinimumLength.Use Then
		ReportSettings.DataParameters.SetParameterValue("ScheduledJobsSessionsMinimumLength", 0);
	EndIf;
	If Not ShowBackgroundJobs.Use Then
		ReportSettings.DataParameters.SetParameterValue("ShowBackgroundJobs", False);
	EndIf;
	If Not HideSceduledJobs.Use Then
		ReportSettings.DataParameters.SetParameterValue("HideSceduledJobs", "");
	EndIf;
	If Not SizeConcurrentSessions.Use Then
		ReportSettings.DataParameters.SetParameterValue("SizeConcurrentSessions", 0);
	EndIf;
		
	If Not ValueIsFilled(BeginSelection.Value) Then
		DayPeriodStartDate = BegOfDay(DayPeriod);
	ElsIf Not BeginSelection.Use Then
		DayPeriodStartDate = BegOfDay(DayPeriod);
	Else
		DayPeriodStartDate = Date(Format(DayPeriod.Date, "DLF=D") + " " + Format(BeginSelection.Value, "DLF=T"));
	EndIf;
	
	If Not ValueIsFilled(EndSelection.Value) Then
		DayEndOfPeriodDate = EndOfDay(DayPeriod);
	ElsIf Not EndSelection.Use Then
		DayEndOfPeriodDate = EndOfDay(DayPeriod);
	Else
		DayEndOfPeriodDate = Date(Format(DayPeriod.Date, "DLF=D") + " " + Format(EndSelection.Value, "DLF=T"));
	EndIf;
	
	FillingParameters = New Structure;
	FillingParameters.Insert("StartDate", DayPeriodStartDate);
	FillingParameters.Insert("EndDate", DayEndOfPeriodDate);
	FillingParameters.Insert("SizeConcurrentSessions", SizeConcurrentSessions.Value);
	FillingParameters.Insert("ScheduledJobsSessionsMinimumLength", 
								  ScheduledJobsSessionsMinimumLength.Value);
	FillingParameters.Insert("ShowBackgroundJobs", ShowBackgroundJobs.Value);
	FillingParameters.Insert("TitleOutput", TitleOutput);
	FillingParameters.Insert("FilterOutput", FilterOutput);
	FillingParameters.Insert("ReportHeader", ReportHeader);
	FillingParameters.Insert("HideSceduledJobs", HideSceduledJobs.Value);
	
	FormingResultReport = Reports.EventsLogAnalysis.
									GenerateReportForDurationJobsOfScheduledJobs(FillingParameters);
	ResultDocument.Put(FormingResultReport.Report);
EndProcedure    

#EndRegion

#EndIf