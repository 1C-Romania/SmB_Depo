
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure imports the form settings.
//
&AtServer
Procedure ImportFormSettings()
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	UserEmployees.Employee
	|FROM
	|	InformationRegister.UserEmployees AS UserEmployees
	|WHERE
	|	UserEmployees.User = &User";
	Query.SetParameter("User", Users.CurrentUser());
	
	SettingsStructure = FormDataSettingsStorage.Load("DataProcessorEmployeeCalendarForm", "SettingsStructure");
	
	If TypeOf(SettingsStructure) = Type("Structure") Then
		
		RadioButton = "Day";
		
		If SettingsStructure.Property("WorkSchedulePeriodMonthCheck")
			AND SettingsStructure.WorkSchedulePeriodMonthCheck Then
			RadioButton = "Month";
		EndIf;
		
		If SettingsStructure.Property("WorkSchedulePeriodWeekCheck")
			AND SettingsStructure.WorkSchedulePeriodWeekCheck Then
			RadioButton = "Week";
		EndIf;
		
		// Filters.
		If SettingsStructure.Property("Counterparty") Then
			FilterCounterparty = SettingsStructure.Counterparty;
		EndIf;
		If SettingsStructure.Property("Employee") Then
			FilterEmployee = SettingsStructure.Employee;
		EndIf;
		If SettingsStructure.Property("State") Then
			FilterState = SettingsStructure.State;
		EndIf;
		If SettingsStructure.Property("EventType") Then
			FilterEventType = SettingsStructure.EventType;
		EndIf;
		
		If SettingsStructure.Property("EmployeesList") Then
			For Each ArrayRow IN SettingsStructure.EmployeesList Do
				NewRow = EmployeesList.Add();
				FillPropertyValues(NewRow, ArrayRow);
			EndDo;
		Else
			SelectionOfQueryResult = Query.Execute().Select();
			While SelectionOfQueryResult.Next() Do
				NewRow = EmployeesList.Add();
				NewRow.Show = True;
				NewRow.Employee = SelectionOfQueryResult.Employee;
			EndDo;
		EndIf;
		
	Else
		RadioButton = "Day";
		SelectionOfQueryResult = Query.Execute().Select();
		While SelectionOfQueryResult.Next() Do
			NewRow = EmployeesList.Add();
			NewRow.Show = True;
			NewRow.Employee = SelectionOfQueryResult.Employee;
		EndDo;
	EndIf;
	
	If Not ValueIsFilled(RadioButton) Then
		RadioButton = "Day";
	EndIf;
	
EndProcedure // ImportFormSettings()

// Procedure saves the form settings.
//
&AtServerNoContext
Procedure SaveFormSettings(SettingsStructure)
	
	FormDataSettingsStorage.Save("DataProcessorEmployeeCalendarForm", "SettingsStructure", SettingsStructure);
	
EndProcedure // SaveFormSettings()

// Procedure fills the period presentation.
//
&AtClient
Procedure FillPresentationOfPeriod()
	
	If RadioButton = "Month" Then
		MonthOfSchedule = Format(DateOfSchedule, "DF=MMM");
		YearOfSchedule = Format(Year(DateOfSchedule), "NG=0");
		PeriodPresentation = MonthOfSchedule + " " + YearOfSchedule;
	ElsIf RadioButton = "Week" Then
		CalendarDateBegin = BegOfWeek(DateOfSchedule);
		CalendarDateEnd = EndOfWeek(DateOfSchedule);
		If Month(CalendarDateBegin) = Month(CalendarDateEnd) Then
			DayOfScheduleBegin = Format(CalendarDateBegin, "DF=dd");
			DayOfScheduleEnd = Format(CalendarDateEnd, "DF=dd");
			MonthOfScheduleEnd = Format(CalendarDateEnd, "DF=MMM");
			YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
			PeriodPresentation = DayOfScheduleBegin + " - " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + ", " + YearOfSchedule;
		Else
			DayOfScheduleBegin = Format(CalendarDateBegin, "DF=dd");
			MonthOfScheduleBegin = Format(CalendarDateBegin, "DF=MMM");
			DayOfScheduleEnd = Format(CalendarDateEnd, "DF=dd");
			MonthOfScheduleEnd = Format(CalendarDateEnd, "DF=MMM");
			If Year(CalendarDateBegin) = Year(CalendarDateEnd) Then
				YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
				PeriodPresentation = DayOfScheduleBegin + " " + MonthOfScheduleBegin + " - " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + ", " + YearOfSchedule;
			Else
				YearOfScheduleBegin = Format(Year(CalendarDateBegin), "NG=0");
				YearOfScheduleEnd = Format(Year(CalendarDateEnd), "NG=0");
				PeriodPresentation = DayOfScheduleBegin + " " + MonthOfScheduleBegin + " " + YearOfScheduleBegin + " - " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + " " + YearOfScheduleEnd;
				
			EndIf;
		EndIf;
	ElsIf RadioButton = "Day" Then
		DayOfSchedule = Format(DateOfSchedule, "DF=dd");
		MonthOfSchedule = Format(DateOfSchedule, "DF=MMM");
		YearOfSchedule = Format(Year(DateOfSchedule), "NG=0");
		WeekDayOfSchedule = SmallBusinessClient.GetPresentationOfWeekDay(DateOfSchedule);
		PeriodPresentation = WeekDayOfSchedule + " " + DayOfSchedule + " " + MonthOfSchedule + " " + YearOfSchedule;
	EndIf;
	
EndProcedure // FillPeriodPresentation()

// Procedure displays the contacts manager.
//
&AtServer
Procedure RepresentContactsManager()
	
	RepresentMyAgenda();
	If RadioButton = "Day" Then
		RepresentScheduleDay();
	ElsIf RadioButton = "Month" Then
		RepresentScheduleMonth();
	ElsIf RadioButton = "Week" Then
		RepresentScheduleWeek();
	EndIf;
	
EndProcedure // DisplayContactsManager()

// Procedure converts the string into the enumeration.
//
&AtServer
Function StringIntoEnumeration(FilterEventType)
	
	If FilterEventType = "Personal meeting" Then
		Return Enums.EventTypes.PrivateMeeting;
	ElsIf FilterEventType = "Other" Then
		Return Enums.EventTypes.Other;
	ElsIf FilterEventType = "Phone call" Then
		Return Enums.EventTypes.PhoneCall;
	ElsIf FilterEventType = "Email" Then
		Return Enums.EventTypes.Email;
	ElsIf FilterEventType = "Work order" Then
		Return "WorkOrder";
	Else
		Return Enums.EventTypes.EmptyRef();
	EndIf;
	
EndFunction // StringToEnumeration()

// The procedure displays my agenda.
//
&AtServer
Procedure RepresentMyAgenda()
	
	MyCurrentDayTasks.Clear();
	
	Query = New Query();
	
	Query.Text =
	"SELECT
	|	UserEmployees.Employee
	|INTO UserEmployees
	|FROM
	|	InformationRegister.UserEmployees AS UserEmployees
	|WHERE
	|	UserEmployees.User = &User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.Order AS Order,
	|	NestedSelect.Number AS Number,
	|	NestedSelect.LineNumber AS LineNumber,
	|	NestedSelect.Ref AS Ref,
	|	NestedSelect.CounterpartyPresentation AS CounterpartyPresentation,
	|	NestedSelect.Subject AS Subject,
	|	NestedSelect.Content AS Content,
	|	NestedSelect.Responsible AS Responsible,
	|	NestedSelect.ProductsAndServicesPresentation AS ProductsAndServicesPresentation,
	|	NestedSelect.Comment AS Comment,
	|	NestedSelect.CommentOfDocument AS CommentOfDocument,
	|	NestedSelect.CustomerPresentation AS CustomerPresentation,
	|	NestedSelect.Day AS Day,
	|	NestedSelect.BeginTime AS BeginTime,
	|	NestedSelect.EndTime AS EndTime,
	|	NestedSelect.Closed AS Closed
	|FROM
	|	(SELECT
	|		1 AS Order,
	|		Event.Number AS Number,
	|		1 AS LineNumber,
	|		Event.Ref AS Ref,
	|		CASE
	|			WHEN VALUETYPE(EventParties.Contact) <> Type(Catalog.Counterparties)
	|					OR EventParties.Contact = VALUE(Catalog.Counterparties.EmptyRef)
	|				THEN ""<Not specified>""
	|			ELSE PRESENTATION(EventParties.Contact)
	|		END AS CounterpartyPresentation,
	|		CASE
	|			WHEN Event.Subject = """"
	|				THEN ""<The subject is not specified>""
	|			ELSE Event.Subject
	|		END AS Subject,
	|		CASE
	|			WHEN (CAST(Event.Content AS String(255))) = """"
	|				THEN ""<Content is not specified>""
	|			ELSE CAST(Event.Content AS String(255))
	|		END AS Content,
	|		Event.Responsible AS Responsible,
	|		UNDEFINED AS ProductsAndServicesPresentation,
	|		UNDEFINED AS Comment,
	|		UNDEFINED AS CommentOfDocument,
	|		UNDEFINED AS CustomerPresentation,
	|		UNDEFINED AS Day,
	|		Event.EventBegin AS BeginTime,
	|		Event.EventEnding AS EndTime,
	|		UNDEFINED AS Closed
	|	FROM
	|		Document.Event AS Event
	|			LEFT JOIN Document.Event.Parties AS EventParties
	|			ON Event.Ref = EventParties.Ref
	|				AND (EventParties.LineNumber = 1)
	|	WHERE
	|		Event.Responsible In
	|				(SELECT
	|					UserEmployees.Employee
	|				FROM
	|					UserEmployees)
	|		AND Event.DeletionMark = FALSE
	|		AND Event.EventBegin >= &BeginTime
	|		AND Event.EventBegin <= &EndTime
	|		AND (&State = VALUE(Catalog.EventStates.EmptyRef)
	|				OR Event.State = &State)
	|		AND (&EventType = VALUE(Enum.EventTypes.EmptyRef)
	|				OR Event.EventType = &EventType)
	|		AND (&Counterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|				OR EventParties.Contact = &Counterparty)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		2,
	|		JobOrderWorks.Ref.Number,
	|		JobOrderWorks.LineNumber,
	|		JobOrderWorks.Ref,
	|		UNDEFINED,
	|		UNDEFINED,
	|		UNDEFINED,
	|		JobOrderWorks.Ref.Employee,
	|		PRESENTATION(JobOrderWorks.ProductsAndServices),
	|		CAST(JobOrderWorks.Comment AS String(255)),
	|		CAST(JobOrderWorks.Ref.Comment AS String(255)),
	|		PRESENTATION(JobOrderWorks.Customer),
	|		JobOrderWorks.Day,
	|		DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.BeginTime) * 3600 + MINUTE(JobOrderWorks.BeginTime) * 60 + Second(JobOrderWorks.BeginTime)),
	|		DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.EndTime) * 3600 + MINUTE(JobOrderWorks.EndTime) * 60 + Second(JobOrderWorks.EndTime)),
	|		CASE
	|			WHEN JobOrderWorks.Ref.State = VALUE(Catalog.EventStates.Completed)
	|				THEN TRUE
	|			ELSE FALSE
	|		END
	|	FROM
	|		Document.WorkOrder.Works AS JobOrderWorks
	|	WHERE
	|		JobOrderWorks.Ref.Posted = TRUE
	|		AND JobOrderWorks.Ref.Employee In
	|				(SELECT
	|					UserEmployees.Employee
	|				FROM
	|					UserEmployees)
	|		AND DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.BeginTime) * 3600 + MINUTE(JobOrderWorks.BeginTime) * 60 + Second(JobOrderWorks.BeginTime)) >= &BeginTime
	|		AND DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.EndTime) * 3600 + MINUTE(JobOrderWorks.EndTime) * 60 + Second(JobOrderWorks.EndTime)) <= &EndTime
	|		AND (&Counterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|				OR JobOrderWorks.Customer = &Counterparty)
	|		AND (&EventType = VALUE(Enum.EventTypes.EmptyRef)
	|				OR &EventType = ""WorkOrder"")
	|		AND (&State = VALUE(Catalog.EventStates.EmptyRef)
	|				OR JobOrderWorks.Ref.State = &State)) AS NestedSelect
	|
	|ORDER BY
	|	Order,
	|	Day,
	|	BeginTime,
	|	EndTime,
	|	Number,
	|	LineNumber
	|TOTALS BY
	|	BeginTime,
	|	Order";
	
	Query.SetParameter("User", Users.CurrentUser());
	Query.SetParameter("DateOfSchedule", DateOfSchedule);
	Query.SetParameter("Counterparty", FilterCounterparty);
	Query.SetParameter("EventType", StringIntoEnumeration(FilterEventType));
	Query.SetParameter("State", FilterState);
	
	If RadioButton = "Day" Then
		Query.SetParameter("BeginTime", BegOfDay(DateOfSchedule));
		Query.SetParameter("EndTime", EndOfDay(DateOfSchedule));
	ElsIf RadioButton = "Week" Then
		Query.SetParameter("BeginTime", BegOfWeek(DateOfSchedule));
		Query.SetParameter("EndTime", EndOfWeek(DateOfSchedule));
	Else
		Query.SetParameter("BeginTime", BegOfMonth(DateOfSchedule));
		Query.SetParameter("EndTime", EndOfMonth(DateOfSchedule));
	EndIf;
	
	QueryResultt = Query.Execute();
	
	TemplateMyCurrentDayTasks = DataProcessors.EmployeeCalendar.GetTemplate("MyCurrentDayTasks");
	
	If QueryResultt.IsEmpty() Then
		TemplateArea = TemplateMyCurrentDayTasks.GetArea("RowEmptyPeriod");
		MyCurrentDayTasks.Put(TemplateArea);
		Return;
	EndIf;
	
	SelectionByDate = QueryResultt.Select(QueryResultIteration.ByGroups);
	DateCount = SelectionByDate.Count();
	
	While SelectionByDate.Next() Do
		
		If DateCount > 1 Then
			TemplateArea = TemplateMyCurrentDayTasks.GetArea("GroupDate");
			TemplateArea.Parameters.Date = String(Format(SelectionByDate.BeginTime, "DF=dd:MM:yyyy"));
			MyCurrentDayTasks.Put(TemplateArea);
			MyCurrentDayTasks.StartRowGroup();
		EndIf;
		
		SelectionByOrder = SelectionByDate.Select(QueryResultIteration.ByGroups);
		
		While SelectionByOrder.Next() Do
			
			If SelectionByOrder.Order = 1 Then
				
				SelectionOfQueryResult = SelectionByOrder.Select();
				
				TemplateArea = TemplateMyCurrentDayTasks.GetArea("GroupEvents");
				TemplateArea.Parameters.EventsQuantity = String(SelectionOfQueryResult.Count());
				MyCurrentDayTasks.Put(TemplateArea);
				
				MyCurrentDayTasks.StartRowGroup();
				
				While SelectionOfQueryResult.Next() Do
				
					TemplateArea = TemplateMyCurrentDayTasks.GetArea("RowEvent");
					TemplateArea.Parameters.Subject = SelectionOfQueryResult.Subject;
					
					If BegOfDay(SelectionByDate.BeginTime) = BegOfDay(SelectionOfQueryResult.BeginTime)
					   AND BegOfDay(SelectionByDate.BeginTime) = BegOfDay(SelectionOfQueryResult.EndTime) Then
						TemplateArea.Parameters.Period = "" + Format(SelectionOfQueryResult.BeginTime, "DF=HH:mm") + " - " + Format(SelectionOfQueryResult.EndTime, "DF=HH:mm");
					Else
						TemplateArea.Parameters.Period = "" + Format(SelectionOfQueryResult.BeginTime, "DF=HH:mm") + " " + Format(SelectionOfQueryResult.BeginTime, "DF=dd:MM:yyyy") + " - " + Format(SelectionOfQueryResult.EndTime, "DF=HH:mm") + " " + Format(SelectionOfQueryResult.EndTime, "DF=dd:MM:yyyy");
					EndIf;
					
					TemplateArea.Parameters.Content = SelectionOfQueryResult.Content;
					TemplateArea.Parameters.Counterparty = SelectionOfQueryResult.CounterpartyPresentation;
					
					MyCurrentDayTasks.Put(TemplateArea);
					
					DetailsStructure = New Structure;
					DetailsStructure.Insert("DocumentRef", SelectionOfQueryResult.Ref);
					CellCoordinates = "R" + String(MyCurrentDayTasks.TableHeight - 3) + "C10";
					MyCurrentDayTasks.Area(CellCoordinates).Details = DetailsStructure;
					
					If SelectionOfQueryResult.EndTime < DateOfSchedule Then
						MarkCompletedJob(MyCurrentDayTasks.TableHeight - 3, False, StyleColorPastEvent, "MyCurrentDayTasks");
					EndIf;
					
				EndDo;
				
				MyCurrentDayTasks.EndRowGroup();
				
			ElsIf SelectionByOrder.Order = 2 Then
				
				SelectionOfQueryResult = SelectionByOrder.Select();
				TemplateArea = TemplateMyCurrentDayTasks.GetArea("GroupTasks");
				TemplateArea.Parameters.TasksQuantity = String(SelectionOfQueryResult.Count());
				MyCurrentDayTasks.Put(TemplateArea);
				MyCurrentDayTasks.StartRowGroup();
				
				While SelectionOfQueryResult.Next() Do
				
					TemplateArea = TemplateMyCurrentDayTasks.GetArea("RowTask");
					
					If ValueIsFilled(SelectionOfQueryResult.ProductsAndServicesPresentation) Then
						TemplateArea.Parameters.Description = SelectionOfQueryResult.ProductsAndServicesPresentation;
					ElsIf ValueIsFilled(SelectionOfQueryResult.Comment) Then
						TemplateArea.Parameters.Description = SelectionOfQueryResult.Comment;
					ElsIf ValueIsFilled(SelectionOfQueryResult.CommentOfDocument) Then
						TemplateArea.Parameters.Description = SelectionOfQueryResult.CommentOfDocument;
					Else
						TemplateArea.Parameters.Description = "<Name is not specified>";
					EndIf;
					
					If BegOfDay(SelectionByDate.BeginTime) = BegOfDay(SelectionOfQueryResult.EndTime) Then
						TemplateArea.Parameters.Period = "" + Format(SelectionOfQueryResult.EndTime, "DF=HH:mm");
					Else
						TemplateArea.Parameters.Period = "" + Format(SelectionOfQueryResult.EndTime, "DF=HH:mm") + " " + Format(SelectionOfQueryResult.Day, "DLF=D");
					EndIf;
					
					If ValueIsFilled(SelectionOfQueryResult.CommentOfDocument) Then
						TemplateArea.Parameters.Definition = SelectionOfQueryResult.CommentOfDocument;
					ElsIf ValueIsFilled(SelectionOfQueryResult.Comment) Then
						TemplateArea.Parameters.Definition = SelectionOfQueryResult.Comment;
					ElsIf ValueIsFilled(SelectionOfQueryResult.ProductsAndServicesPresentation) Then
						TemplateArea.Parameters.Definition = SelectionOfQueryResult.ProductsAndServicesPresentation;
					Else
						TemplateArea.Parameters.Definition = "<Description is not specified>";
					EndIf;
					
					TemplateArea.Parameters.Counterparty = ?(ValueIsFilled(SelectionOfQueryResult.CustomerPresentation), SelectionOfQueryResult.CustomerPresentation, "<Not specified>");
					
					If SelectionOfQueryResult.Closed Then
						TemplateArea.Parameters.Flag = "";
					Else
						TemplateArea.Parameters.Flag = "";
					EndIf;
					
					MyCurrentDayTasks.Put(TemplateArea);
					
					DetailsStructure = New Structure;
					DetailsStructure.Insert("DocumentRef", SelectionOfQueryResult.Ref);
					DetailsStructure.Insert("Date", SelectionOfQueryResult.EndTime);
					CellCoordinates = "R" + String(MyCurrentDayTasks.TableHeight - 3) + "C10";
					MyCurrentDayTasks.Area(CellCoordinates).Details = DetailsStructure;
					
					If SelectionOfQueryResult.Closed Then
						MarkCompletedJob(MyCurrentDayTasks.TableHeight - 3, True, StyleColorCompletedJob, "MyCurrentDayTasks");
					ElsIf SelectionOfQueryResult.EndTime < DateOfSchedule Then
						MarkCompletedJob(MyCurrentDayTasks.TableHeight - 3, False, StyleColorOverdueJob, "MyCurrentDayTasks");
					EndIf;
				
				EndDo;
			
				MyCurrentDayTasks.EndRowGroup();
				
			EndIf;
			
		EndDo;
		
		If DateCount > 1 Then
			MyCurrentDayTasks.EndRowGroup();
		EndIf;
		
	EndDo;
	
EndProcedure // DisplayMyAgenda()

// Procedure displays the schedule of the Day kind.
//
&AtServer
Procedure RepresentScheduleDay()
	
	Schedule.Clear();
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	NestedSelect.Order AS Order,
	|	NestedSelect.Number AS Number,
	|	NestedSelect.LineNumber AS LineNumber,
	|	NestedSelect.Ref AS Ref,
	|	NestedSelect.CounterpartyPresentation AS CounterpartyPresentation,
	|	NestedSelect.Subject AS Subject,
	|	NestedSelect.Content AS Content,
	|	Employees.Ref AS Responsible,
	|	PRESENTATION(Employees.Ref) AS ResponsiblePresentation,
	|	NestedSelect.ProductsAndServicesPresentation AS ProductsAndServicesPresentation,
	|	NestedSelect.Comment AS Comment,
	|	NestedSelect.CommentOfDocument AS CommentOfDocument,
	|	NestedSelect.CustomerPresentation AS CustomerPresentation,
	|	NestedSelect.Day AS Day,
	|	NestedSelect.BeginTime AS BeginTime,
	|	NestedSelect.EndTime AS EndTime,
	|	NestedSelect.Closed AS Closed
	|FROM
	|	Catalog.Employees AS Employees
	|		LEFT JOIN (SELECT
	|			1 AS Order,
	|			Event.Number AS Number,
	|			1 AS LineNumber,
	|			Event.Ref AS Ref,
	|			CASE
	|				WHEN VALUETYPE(EventParties.Contact) <> Type(Catalog.Counterparties)
	|						OR EventParties.Contact = VALUE(Catalog.Counterparties.EmptyRef)
	|					THEN ""<Not specified>""
	|				ELSE PRESENTATION(EventParties.Contact)
	|			END AS CounterpartyPresentation,
	|			CASE
	|				WHEN Event.Subject = """"
	|					THEN ""<The subject is not specified>""
	|				ELSE Event.Subject
	|			END AS Subject,
	|			CASE
	|				WHEN (CAST(Event.Content AS String(255))) = """"
	|					THEN ""<Content is not specified>""
	|				ELSE CAST(Event.Content AS String(255))
	|			END AS Content,
	|			Event.Responsible AS Responsible,
	|			UNDEFINED AS ProductsAndServicesPresentation,
	|			UNDEFINED AS Comment,
	|			UNDEFINED AS CommentOfDocument,
	|			UNDEFINED AS CustomerPresentation,
	|			UNDEFINED AS Day,
	|			Event.EventBegin AS BeginTime,
	|			Event.EventEnding AS EndTime,
	|			UNDEFINED AS Closed
	|		FROM
	|			Document.Event AS Event
	|				LEFT JOIN Document.Event.Parties AS EventParties
	|				ON Event.Ref = EventParties.Ref
	|					AND (EventParties.LineNumber = 1)
	|		WHERE
	|			Event.Responsible IN (&EmployeesList)
	|			AND Event.DeletionMark = FALSE
	|			AND Event.EventBegin >= &BeginTime
	|			AND Event.EventBegin <= &EndTime
	|			AND (&State = VALUE(Catalog.EventStates.EmptyRef)
	|					OR Event.State = &State)
	|			AND (&EventType = VALUE(Enum.EventTypes.EmptyRef)
	|					OR Event.EventType = &EventType)
	|			AND (&Counterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|					OR EventParties.Contact = &Counterparty)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			2,
	|			JobOrderWorks.Ref.Number,
	|			JobOrderWorks.LineNumber,
	|			JobOrderWorks.Ref,
	|			UNDEFINED,
	|			UNDEFINED,
	|			UNDEFINED,
	|			JobOrderWorks.Ref.Employee,
	|			PRESENTATION(JobOrderWorks.ProductsAndServices),
	|			CAST(JobOrderWorks.Comment AS String(255)),
	|			CAST(JobOrderWorks.Ref.Comment AS String(255)),
	|			PRESENTATION(JobOrderWorks.Customer),
	|			JobOrderWorks.Day,
	|			DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.BeginTime) * 3600 + MINUTE(JobOrderWorks.BeginTime) * 60 + Second(JobOrderWorks.BeginTime)),
	|			DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.EndTime) * 3600 + MINUTE(JobOrderWorks.EndTime) * 60 + Second(JobOrderWorks.EndTime)),
	|			CASE
	|				WHEN JobOrderWorks.Ref.State = VALUE(Catalog.EventStates.Completed)
	|					THEN TRUE
	|				ELSE FALSE
	|			END
	|		FROM
	|			Document.WorkOrder.Works AS JobOrderWorks
	|		WHERE
	|			JobOrderWorks.Ref.Posted = TRUE
	|			AND JobOrderWorks.Ref.Employee IN (&EmployeesList)
	|			AND DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.BeginTime) * 3600 + MINUTE(JobOrderWorks.BeginTime) * 60 + Second(JobOrderWorks.BeginTime)) >= &BeginTime
	|			AND DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.EndTime) * 3600 + MINUTE(JobOrderWorks.EndTime) * 60 + Second(JobOrderWorks.EndTime)) <= &EndTime
	|			AND (&Counterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|					OR JobOrderWorks.Customer = &Counterparty)
	|			AND (&EventType = VALUE(Enum.EventTypes.EmptyRef)
	|					OR &EventType = ""WorkOrder"")
	|			AND (&State = VALUE(Catalog.EventStates.EmptyRef)
	|					OR JobOrderWorks.Ref.State = &State)) AS NestedSelect
	|		ON (NestedSelect.Responsible = Employees.Ref)
	|WHERE
	|	Employees.Ref IN(&EmployeesList)
	|
	|ORDER BY
	|	Responsible,
	|	Order,
	|	Day,
	|	BeginTime,
	|	EndTime,
	|	Number,
	|	LineNumber
	|TOTALS BY
	|	Responsible,
	|	Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(DeviationFromResourcesWorkSchedules.BeginTime, WorkSchedules.BeginTime) AS BeginTime,
	|	ISNULL(DeviationFromResourcesWorkSchedules.EndTime, WorkSchedules.EndTime) AS EndTime,
	|	ISNULL(DeviationFromResourcesWorkSchedules.NotABusinessDay, FALSE) AS NotABusinessDay,
	|	RecourcesWorkScheduleSliceLast.EnterpriseResource.ResourceValue AS Employee
	|FROM
	|	InformationRegister.ResourcesWorkSchedules.SliceLast(&DateOfSchedule, ) AS RecourcesWorkScheduleSliceLast
	|		LEFT JOIN InformationRegister.WorkSchedules AS WorkSchedules
	|		ON RecourcesWorkScheduleSliceLast.WorkSchedule = WorkSchedules.WorkSchedule
	|		LEFT JOIN InformationRegister.DeviationFromResourcesWorkSchedules AS DeviationFromResourcesWorkSchedules
	|		ON RecourcesWorkScheduleSliceLast.EnterpriseResource = DeviationFromResourcesWorkSchedules.EnterpriseResource
	|			AND (YEAR(RecourcesWorkScheduleSliceLast.Period) = DeviationFromResourcesWorkSchedules.Year)
	|			AND (DeviationFromResourcesWorkSchedules.Day = BEGINOFPERIOD(&DateOfSchedule, Day))
	|WHERE
	|	WorkSchedules.Year = YEAR(&DateOfSchedule)
	|	AND WorkSchedules.BeginTime >= &BeginTime
	|	AND WorkSchedules.EndTime <= &EndTime";
	
	User = Users.CurrentUser();
	Responsible = SmallBusinessReUse.GetValueByDefaultUser(User, "MainResponsible");
	EmployeeArray = New Array();
	
	If ValueIsFilled(FilterEmployee) Then
		EmployeeArray.Add(FilterEmployee);
	Else
		For Each RowEmployee IN EmployeesList Do
			If RowEmployee.Show Then
				EmployeeArray.Add(RowEmployee.Employee);
			EndIf;
		EndDo;
	EndIf;
	
	TemplateSchedule = DataProcessors.EmployeeCalendar.GetTemplate("DaySchedule");
	
	If EmployeeArray.Count() = 0 Then
		TemplateArea = TemplateSchedule.GetArea("RowFilterIsEmpty");
		Schedule.Put(TemplateArea);
		Return;
	EndIf;
	
	Query.SetParameter("Responsible", Responsible);
	Query.SetParameter("DateOfSchedule", DateOfSchedule);
	Query.SetParameter("BeginTime", BegOfDay(DateOfSchedule));
	Query.SetParameter("EndTime", EndOfDay(DateOfSchedule));
	Query.SetParameter("EmployeesList", EmployeeArray);
	Query.SetParameter("Counterparty", FilterCounterparty);
	Query.SetParameter("EventType", StringIntoEnumeration(FilterEventType));
	Query.SetParameter("State", FilterState);
	
	QueryResultt = Query.ExecuteBatch();
	
	TemplateArea = TemplateSchedule.GetArea("Header");
	Schedule.Put(TemplateArea);
	
	IterationByResponsible = QueryResultt[0].Select(QueryResultIteration.ByGroups);
	
	TableWorkSchedules = QueryResultt[1].Unload();
	
	TableWorkSchedules.Indexes.Add("Employee");
	
	While IterationByResponsible.Next() Do
		
		TemplateArea = TemplateSchedule.GetArea("GroupName");
		TemplateArea.Parameters.Name = IterationByResponsible.ResponsiblePresentation;
		Schedule.Put(TemplateArea);
		
		For Ct = 7 To 54 Do
		
			DetailsStructure = New Structure;
			DetailsStructure.Insert("Responsible", IterationByResponsible.Responsible);
			DetailsStructure.Insert("Period", DateOfSchedule + (Ct - 7) * 1800);
			CellCoordinates = "R" + String(Schedule.TableHeight) + "C" + String(Ct);
			Schedule.Area(CellCoordinates).Details = DetailsStructure;
		
		EndDo;
		
		ArrayOfGraphIntervals = TableWorkSchedules.FindRows(New Structure("Employee", IterationByResponsible.Responsible));
		
		TitleLineNumber = Schedule.TableHeight;
		Schedule.StartRowGroup(, ?(IterationByResponsible.Responsible = Responsible, True, False));
		
		IterationByOrder = IterationByResponsible.Select(QueryResultIteration.ByGroups);
		
		While IterationByOrder.Next() Do
			
			If IterationByOrder.Order = 1 Then
				
				SelectionOfQueryResult = IterationByOrder.Select();
				
				TemplateArea = TemplateSchedule.GetArea("GroupEvent");
				TemplateArea.Parameters.EventsQuantity = String(SelectionOfQueryResult.Count());
				Schedule.Put(TemplateArea);
				
				Schedule.StartRowGroup();
				
				While SelectionOfQueryResult.Next() Do
					
					TemplateArea = TemplateSchedule.GetArea("RowEvent");
					TemplateArea.Parameters.Subject = SelectionOfQueryResult.Subject;
					
					If BegOfDay(DateOfSchedule) = BegOfDay(SelectionOfQueryResult.BeginTime)
					   AND BegOfDay(DateOfSchedule) = BegOfDay(SelectionOfQueryResult.EndTime) Then
						TemplateArea.Parameters.Period = "" + Format(SelectionOfQueryResult.BeginTime, "DF=HH:mm") + " - " + Format(SelectionOfQueryResult.EndTime, "DF=HH:mm");
					Else
						TemplateArea.Parameters.Period = "" + Format(SelectionOfQueryResult.BeginTime, "DF=HH:mm") + " " + Format(SelectionOfQueryResult.BeginTime, "DF=dd:MM:yyyy") + " - " + Format(SelectionOfQueryResult.EndTime, "DF=HH:mm") + " " + Format(SelectionOfQueryResult.EndTime, "DF=dd:MM:yyyy");
					EndIf;
					
					TemplateArea.Parameters.Content = SelectionOfQueryResult.Content;
					TemplateArea.Parameters.Counterparty = SelectionOfQueryResult.CounterpartyPresentation;
					
					Schedule.Put(TemplateArea);
					
					DetailsStructure = New Structure;
					DetailsStructure.Insert("DocumentRef", SelectionOfQueryResult.Ref);
					CellCoordinates = "R" + String(Schedule.TableHeight - 1) + "C49";
					Schedule.Area(CellCoordinates).Details = DetailsStructure;
					
					If SelectionOfQueryResult.EndTime < DateOfSchedule Then
						MarkCompletedJob(Schedule.TableHeight - 1, False, StyleColorPastEvent, "Schedule");
					EndIf;
					
					For Ct = 0 To 47 Do
						
						CurIntervalBegin = BegOfDay(DateOfSchedule) + Ct * 1800;
						CurIntervalEnd = BegOfDay(DateOfSchedule) + Ct * 1800 + 1799;
						
						For Each CurInterval IN ArrayOfGraphIntervals Do
							
							If CurIntervalBegin >= CurInterval.BeginTime
							   AND CurIntervalEnd <= CurInterval.EndTime
							   AND Not CurInterval.NotABusinessDay Then
								
								Area = Schedule.Area("R" + String(TitleLineNumber) + "C" + String(Ct + 7));
								
								If Area.BackColor <> StyleColors.WorktimeCompletelyBusy Then
									Area.BackColor = StyleColors.WorktimeCompletelyBusy;
								EndIf;
								
							EndIf;
							
						EndDo;
						
						If CurIntervalBegin >= SelectionOfQueryResult.BeginTime
						  AND CurIntervalEnd <= SelectionOfQueryResult.EndTime Then
							
							Area = Schedule.Area("R" + String(TitleLineNumber) + "C" + String(Ct + 7));
							
							If Area.BackColor <> StyleColors.ScheduledTime Then
								Area.BackColor = StyleColors.ScheduledTime;
							EndIf;
							
						EndIf;
						
					EndDo;
					
				EndDo;
				
				Schedule.EndRowGroup();
				
			ElsIf IterationByOrder.Order = 2 Then
			
				SelectionOfQueryResult = IterationByOrder.Select();
				
				TemplateArea = TemplateSchedule.GetArea("GroupTasks");
				
				TemplateArea.Parameters.TasksQuantity = String(SelectionOfQueryResult.Count());
				Schedule.Put(TemplateArea);
				Schedule.StartRowGroup();
				
				While SelectionOfQueryResult.Next() Do
					
					TemplateArea = TemplateSchedule.GetArea("RowTask");
					
					If ValueIsFilled(SelectionOfQueryResult.ProductsAndServicesPresentation) Then
						TemplateArea.Parameters.Description = SelectionOfQueryResult.ProductsAndServicesPresentation;
					ElsIf ValueIsFilled(SelectionOfQueryResult.Comment) Then
						TemplateArea.Parameters.Description = SelectionOfQueryResult.Comment;
					ElsIf ValueIsFilled(SelectionOfQueryResult.CommentOfDocument) Then
						TemplateArea.Parameters.Description = SelectionOfQueryResult.CommentOfDocument;
					Else
						TemplateArea.Parameters.Description = "<Name is not specified>";
					EndIf;
					
					If BegOfDay(DateOfSchedule) = BegOfDay(SelectionOfQueryResult.EndTime) Then
						TemplateArea.Parameters.Period = "" + Format(SelectionOfQueryResult.EndTime, "DF=HH:mm");
					Else
						TemplateArea.Parameters.Period = "" + Format(SelectionOfQueryResult.EndTime, "DF=HH:mm") + " " + Format(SelectionOfQueryResult.Day, "DLF=D");
					EndIf;
					
					If ValueIsFilled(SelectionOfQueryResult.CommentOfDocument) Then
						TemplateArea.Parameters.Definition = SelectionOfQueryResult.CommentOfDocument;
					ElsIf ValueIsFilled(SelectionOfQueryResult.Comment) Then
						TemplateArea.Parameters.Definition = SelectionOfQueryResult.Comment;
					ElsIf ValueIsFilled(SelectionOfQueryResult.ProductsAndServicesPresentation) Then
						TemplateArea.Parameters.Definition = SelectionOfQueryResult.ProductsAndServicesPresentation;
					Else
						TemplateArea.Parameters.Definition = "<Description is not specified>";
					EndIf;
					
					BeginTime = SelectionOfQueryResult.Day + Hour(SelectionOfQueryResult.BeginTime) * 3600 + Minute(SelectionOfQueryResult.BeginTime) * 60 + Second(SelectionOfQueryResult.BeginTime);
					EndTime = SelectionOfQueryResult.Day + Hour(SelectionOfQueryResult.EndTime) * 3600 + Minute(SelectionOfQueryResult.EndTime) * 60 + Second(SelectionOfQueryResult.EndTime);
					
					TemplateArea.Parameters.Counterparty = ?(ValueIsFilled(SelectionOfQueryResult.CustomerPresentation), SelectionOfQueryResult.CustomerPresentation, "<Not specified>");
					
					If SelectionOfQueryResult.Closed Then
						TemplateArea.Parameters.Flag = "";
					Else
						TemplateArea.Parameters.Flag = "";
					EndIf;
					
					Schedule.Put(TemplateArea);
					
					DetailsStructure = New Structure;
					DetailsStructure.Insert("DocumentRef", SelectionOfQueryResult.Ref);
					DetailsStructure.Insert("Date", SelectionOfQueryResult.EndTime);
					CellCoordinates = "R" + String(Schedule.TableHeight - 1) + "C49";
					Schedule.Area(CellCoordinates).Details = DetailsStructure;
					
					If SelectionOfQueryResult.Closed Then
						MarkCompletedJob(Schedule.TableHeight - 1, True, StyleColorCompletedJob, "Schedule");
					ElsIf SelectionOfQueryResult.EndTime < DateOfSchedule Then
						MarkCompletedJob(Schedule.TableHeight - 1, False, StyleColorOverdueJob, "Schedule");
					EndIf;
					
					For Ct = 0 To 47 Do
						
						CurIntervalBegin = BegOfDay(DateOfSchedule) + Ct * 1800;
						CurIntervalEnd = BegOfDay(DateOfSchedule) + Ct * 1800 + 1799;
						
						If CurIntervalBegin >= BeginTime
						  AND CurIntervalEnd <= EndTime Then
							
							Area = Schedule.Area("R" + String(TitleLineNumber) + "C" + String(Ct + 7));
							
							If Area.BackColor <> StyleColors.ScheduledTime Then
								Area.BackColor = StyleColors.ScheduledTime;
							EndIf;
							
						EndIf;
						
					EndDo;
					
				EndDo;
				
				Schedule.EndRowGroup();
				
			EndIf;
			
		EndDo;
		
		Schedule.EndRowGroup();
		
	EndDo;
	
EndProcedure // DisplayScheduleDay()

// Procedure displays the schedule of the Month kind.
//
&AtServer
Procedure RepresentScheduleMonth()
	
	Schedule.Clear();
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	ISNULL(NestedSelect.EventsQuantity, 0) AS EventsQuantity,
	|	ISNULL(NestedSelect.TasksQuantity, 0) AS TasksQuantity,
	|	ISNULL(NestedSelect.ClosedQuantity, 0) AS ClosedQuantity,
	|	ISNULL(NestedSelect.InWorkQuantity, 0) AS InWorkQuantity,
	|	ISNULL(NestedSelect.OverdueQuantity, 0) AS OverdueQuantity,
	|	NestedSelect.Order AS Order,
	|	NestedSelect.Number AS Number,
	|	NestedSelect.LineNumber AS LineNumber,
	|	NestedSelect.Ref AS Ref,
	|	NestedSelect.CounterpartyPresentation AS CounterpartyPresentation,
	|	NestedSelect.Subject AS Subject,
	|	NestedSelect.Content AS Content,
	|	Employees.Ref AS Responsible,
	|	PRESENTATION(Employees.Ref) AS ResponsiblePresentation,
	|	NestedSelect.ProductsAndServicesPresentation AS ProductsAndServicesPresentation,
	|	NestedSelect.Comment AS Comment,
	|	NestedSelect.CommentOfDocument AS CommentOfDocument,
	|	NestedSelect.CustomerPresentation AS CustomerPresentation,
	|	NestedSelect.Day AS Day,
	|	ISNULL(NestedSelect.BeginTime, &BlankDate) AS BeginTime,
	|	ISNULL(NestedSelect.EndTime, &BlankDate) AS EndTime,
	|	NestedSelect.Closed AS Closed
	|FROM
	|	Catalog.Employees AS Employees
	|		LEFT JOIN (SELECT
	|			1 AS EventsQuantity,
	|			0 AS TasksQuantity,
	|			0 AS ClosedQuantity,
	|			0 AS InWorkQuantity,
	|			0 AS OverdueQuantity,
	|			1 AS Order,
	|			Event.Number AS Number,
	|			1 AS LineNumber,
	|			Event.Ref AS Ref,
	|			CASE
	|				WHEN VALUETYPE(EventParties.Contact) <> Type(Catalog.Counterparties)
	|						OR EventParties.Contact = VALUE(Catalog.Counterparties.EmptyRef)
	|					THEN ""<Not specified>""
	|				ELSE PRESENTATION(EventParties.Contact)
	|			END AS CounterpartyPresentation,
	|			CASE
	|				WHEN Event.Subject = """"
	|					THEN ""<The subject is not specified>""
	|				ELSE Event.Subject
	|			END AS Subject,
	|			CASE
	|				WHEN (CAST(Event.Content AS String(255))) = """"
	|					THEN ""<Content is not specified>""
	|				ELSE CAST(Event.Content AS String(255))
	|			END AS Content,
	|			Event.Responsible AS Responsible,
	|			UNDEFINED AS ProductsAndServicesPresentation,
	|			UNDEFINED AS Comment,
	|			UNDEFINED AS CommentOfDocument,
	|			UNDEFINED AS CustomerPresentation,
	|			UNDEFINED AS Day,
	|			Event.EventBegin AS BeginTime,
	|			Event.EventEnding AS EndTime,
	|			UNDEFINED AS Closed
	|		FROM
	|			Document.Event AS Event
	|				LEFT JOIN Document.Event.Parties AS EventParties
	|				ON Event.Ref = EventParties.Ref
	|					AND (EventParties.LineNumber = 1)
	|		WHERE
	|			Event.Responsible IN (&EmployeesList)
	|			AND Event.DeletionMark = FALSE
	|			AND Event.EventBegin >= &BeginOfPeriod
	|			AND Event.EventBegin <= &EndOfPeriod
	|			AND (&State = VALUE(Catalog.EventStates.EmptyRef)
	|					OR Event.State = &State)
	|			AND (&EventType = VALUE(Enum.EventTypes.EmptyRef)
	|					OR Event.EventType = &EventType)
	|			AND (&Counterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|					OR EventParties.Contact = &Counterparty)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			0,
	|			1,
	|			CASE
	|				WHEN JobOrderWorks.Ref.State = VALUE(Catalog.EventStates.Completed)
	|					THEN 1
	|				ELSE 0
	|			END,
	|			CASE
	|				WHEN JobOrderWorks.Ref.State = VALUE(Catalog.EventStates.Completed)
	|					THEN 0
	|				ELSE 1
	|			END,
	|			CASE
	|				WHEN (NOT JobOrderWorks.Ref.State = VALUE(Catalog.EventStates.Completed))
	|						AND DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.EndTime) * 3600 + MINUTE(JobOrderWorks.EndTime) * 60 + Second(JobOrderWorks.EndTime)) > &DateOfSchedule
	|					THEN 1
	|				ELSE 0
	|			END,
	|			2,
	|			JobOrderWorks.Ref.Number,
	|			JobOrderWorks.LineNumber,
	|			JobOrderWorks.Ref,
	|			UNDEFINED,
	|			UNDEFINED,
	|			UNDEFINED,
	|			JobOrderWorks.Ref.Employee,
	|			PRESENTATION(JobOrderWorks.ProductsAndServices),
	|			CAST(JobOrderWorks.Comment AS String(255)),
	|			CAST(JobOrderWorks.Ref.Comment AS String(255)),
	|			PRESENTATION(JobOrderWorks.Customer),
	|			JobOrderWorks.Day,
	|			DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.BeginTime) * 3600 + MINUTE(JobOrderWorks.EndTime) * 60 + Second(JobOrderWorks.EndTime)),
	|			DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.EndTime) * 3600 + MINUTE(JobOrderWorks.EndTime) * 60 + Second(JobOrderWorks.EndTime)),
	|			CASE
	|				WHEN JobOrderWorks.Ref.State = VALUE(Catalog.EventStates.Completed)
	|					THEN TRUE
	|				ELSE FALSE
	|			END
	|		FROM
	|			Document.WorkOrder.Works AS JobOrderWorks
	|		WHERE
	|			JobOrderWorks.Ref.Posted = TRUE
	|			AND DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.BeginTime) * 3600 + MINUTE(JobOrderWorks.EndTime) * 60 + Second(JobOrderWorks.EndTime)) >= &BeginOfPeriod
	|			AND DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.EndTime) * 3600 + MINUTE(JobOrderWorks.EndTime) * 60 + Second(JobOrderWorks.EndTime)) <= &EndOfPeriod
	|			AND JobOrderWorks.Ref.Employee IN(&EmployeesList)
	|			AND (&Counterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|					OR JobOrderWorks.Customer = &Counterparty)
	|			AND (&State = VALUE(Catalog.EventStates.EmptyRef)
	|					OR JobOrderWorks.Ref.State = &State)
	|			AND (&EventType = VALUE(Enum.EventTypes.EmptyRef)
	|					OR &EventType = ""WorkOrder"")) AS NestedSelect
	|		ON (NestedSelect.Responsible = Employees.Ref)
	|WHERE
	|	Employees.Ref IN(&EmployeesList)
	|
	|ORDER BY
	|	Responsible,
	|	Order,
	|	BeginTime,
	|	EndTime,
	|	Number,
	|	LineNumber
	|TOTALS
	|	SUM(EventsQuantity),
	|	SUM(TasksQuantity),
	|	SUM(ClosedQuantity),
	|	SUM(InWorkQuantity),
	|	SUM(OverdueQuantity)
	|BY
	|	Responsible";
	
	User = Users.CurrentUser();
	Responsible = SmallBusinessReUse.GetValueByDefaultUser(User, "MainResponsible");
	EmployeeArray = New Array();
	
	If ValueIsFilled(FilterEmployee) Then
		EmployeeArray.Add(FilterEmployee);
	Else
		For Each RowEmployee IN EmployeesList Do
			If RowEmployee.Show Then
				EmployeeArray.Add(RowEmployee.Employee);
			EndIf;
		EndDo;
	EndIf;
	
	TemplateSchedule = DataProcessors.EmployeeCalendar.GetTemplate("MonthSchedule");
	
	If EmployeeArray.Count() = 0 Then
		TemplateArea = TemplateSchedule.GetArea("RowFilterIsEmpty");
		Schedule.Put(TemplateArea);
		Return;
	EndIf;
	
	Query.SetParameter("DateOfSchedule", DateOfSchedule);
	Query.SetParameter("BeginOfPeriod", BegOfMonth(DateOfSchedule));
	Query.SetParameter("EndOfPeriod", EndOfMonth(DateOfSchedule));
	Query.SetParameter("BlankDate", '00010101');
	Query.SetParameter("EmployeesList", EmployeeArray);
	Query.SetParameter("Counterparty", FilterCounterparty);
	Query.SetParameter("EventType", StringIntoEnumeration(FilterEventType));
	Query.SetParameter("State", FilterState);
	
	QueryResultt = Query.ExecuteBatch();
	
	If WeekDay(BegOfMonth(DateOfSchedule)) > 1 Then
		FirstDateOfMonth = BegOfMonth(DateOfSchedule) - (WeekDay(BegOfMonth(DateOfSchedule)) - 1) * 60 * 60 * 24;
	Else
		FirstDateOfMonth = BegOfMonth(DateOfSchedule);
	EndIf;
	
	TemplateArea = TemplateSchedule.GetArea("Header");
	Schedule.Put(TemplateArea);
	
	IterationByResponsible = QueryResultt[0].Select(QueryResultIteration.ByGroups);
	
	PictureIndex = 0;
	
	While IterationByResponsible.Next() Do
		
		TemplateArea = TemplateSchedule.GetArea("GroupName");
		TemplateArea.Parameters.Name = IterationByResponsible.ResponsiblePresentation;
		TemplateArea.Parameters.EventsQuantity = IterationByResponsible.EventsQuantity;
		TemplateArea.Parameters.TasksQuantity = IterationByResponsible.TasksQuantity;
		TemplateArea.Parameters.ClosedQuantity = IterationByResponsible.ClosedQuantity;
		TemplateArea.Parameters.InWorkQuantity = IterationByResponsible.InWorkQuantity;
		TemplateArea.Parameters.OverdueQuantity = IterationByResponsible.OverdueQuantity;
		Schedule.Put(TemplateArea);
		
		TitleLineNumber = Schedule.TableHeight;
		Schedule.StartRowGroup(, ?(IterationByResponsible.Responsible = Responsible, True, False));
		
		SelectionOfQueryResult = IterationByResponsible.Select();
		
		TemplateArea = TemplateSchedule.GetArea("RowScale");
		
		Schedule.Put(TemplateArea);
		
		For CurWeek = 1 To 6 Do
			
			For CurWeekday = 1 To 7 Do
				
				CurDate = FirstDateOfMonth + ((CurWeek * 7 - 7) + CurWeekday) * 86400 - 86400;
				DayCoordinates = "R" + String(TitleLineNumber + CurWeek * 2 - 1) + "C" + String(CurWeekday * 2);
				DayTextCoordinates = "R" + String(TitleLineNumber + CurWeek * 2) + "C" + String(CurWeekday * 2);
				Schedule.Area(DayCoordinates).Text = Day(CurDate);
				
				DetailsStructure = New Structure;
				DetailsStructure.Insert("Period", CurDate);
				DetailsStructure.Insert("Responsible", IterationByResponsible.Responsible);
				
				Schedule.Area(DayCoordinates).Details = DetailsStructure;
				Schedule.Area(DayTextCoordinates).Details = DetailsStructure;
				
				If BegOfMonth(CurDate) <> BegOfMonth(DateOfSchedule) Then
					Schedule.Area(DayCoordinates).TextColor = New Color(192, 192, 192);
				EndIf;
				
				SelectionOfQueryResult.Reset();
				ListOfEventsAndTasksOfDay = "";
				CtEventsAndJobs = 1;
				EventQuantityAndJobs = SelectionOfQueryResult.Count();
				
				While SelectionOfQueryResult.Next() Do
					
					If BegOfDay(CurDate) >= BegOfDay(SelectionOfQueryResult.BeginTime)
					   AND BegOfDay(CurDate) <= BegOfDay(SelectionOfQueryResult.BeginTime) Then
						
						If CtEventsAndJobs = 6 AND CtEventsAndJobs < EventQuantityAndJobs Then
							ListOfEventsAndTasksOfDay = ListOfEventsAndTasksOfDay + String(CtEventsAndJobs) + ". " + "Yet..." + Chars.LF;
						ElsIf CtEventsAndJobs <= 6 Then
							
							If ValueIsFilled(SelectionOfQueryResult.Subject) Then
								Subject = SelectionOfQueryResult.Subject;
							ElsIf ValueIsFilled(SelectionOfQueryResult.ProductsAndServicesPresentation) Then
								Subject = SelectionOfQueryResult.ProductsAndServicesPresentation;
							ElsIf ValueIsFilled(SelectionOfQueryResult.Comment) Then
								Subject = SelectionOfQueryResult.Comment;
							ElsIf ValueIsFilled(SelectionOfQueryResult.CommentOfDocument) Then
								Subject = SelectionOfQueryResult.CommentOfDocument;
							Else
								Subject = "<Name is not specified>";
							EndIf;
							
							ListOfEventsAndTasksOfDay = ListOfEventsAndTasksOfDay + String(CtEventsAndJobs) + ". " + TrimAll(Subject) + Chars.LF;
						EndIf;
						
						CtEventsAndJobs = CtEventsAndJobs + 1;
						
					EndIf;
					
				EndDo;
				
				If ValueIsFilled(ListOfEventsAndTasksOfDay) Then
					Schedule.Area(DayTextCoordinates).Text = ListOfEventsAndTasksOfDay;
				EndIf;
				
				PictureIndex = PictureIndex + 1;
				
			EndDo;
			
		EndDo;
		
		Schedule.EndRowGroup();
		
	EndDo;
	
EndProcedure // DisplayScheduleMonth()

// Procedure displays the schedule of the Week kind.
//
&AtServer
Procedure RepresentScheduleWeek()
	
	Schedule.Clear();
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	ISNULL(NestedSelect.EventsQuantity, 0) AS EventsQuantity,
	|	ISNULL(NestedSelect.TasksQuantity, 0) AS TasksQuantity,
	|	ISNULL(NestedSelect.ClosedQuantity, 0) AS ClosedQuantity,
	|	ISNULL(NestedSelect.InWorkQuantity, 0) AS InWorkQuantity,
	|	ISNULL(NestedSelect.OverdueQuantity, 0) AS OverdueQuantity,
	|	NestedSelect.Order AS Order,
	|	NestedSelect.Number AS Number,
	|	NestedSelect.LineNumber AS LineNumber,
	|	NestedSelect.Ref AS Ref,
	|	NestedSelect.CounterpartyPresentation AS CounterpartyPresentation,
	|	NestedSelect.Subject AS Subject,
	|	NestedSelect.Content AS Content,
	|	Employees.Ref AS Responsible,
	|	PRESENTATION(Employees.Ref) AS ResponsiblePresentation,
	|	NestedSelect.ProductsAndServicesPresentation AS ProductsAndServicesPresentation,
	|	NestedSelect.Comment AS Comment,
	|	NestedSelect.CommentOfDocument AS CommentOfDocument,
	|	NestedSelect.CustomerPresentation AS CustomerPresentation,
	|	NestedSelect.Day AS Day,
	|	ISNULL(NestedSelect.BeginTime, &BlankDate) AS BeginTime,
	|	ISNULL(NestedSelect.EndTime, &BlankDate) AS EndTime,
	|	NestedSelect.Closed AS Closed
	|FROM
	|	Catalog.Employees AS Employees
	|		LEFT JOIN (SELECT
	|			1 AS EventsQuantity,
	|			0 AS TasksQuantity,
	|			0 AS ClosedQuantity,
	|			0 AS InWorkQuantity,
	|			0 AS OverdueQuantity,
	|			1 AS Order,
	|			Event.Number AS Number,
	|			1 AS LineNumber,
	|			Event.Ref AS Ref,
	|			CASE
	|				WHEN VALUETYPE(EventParties.Contact) <> Type(Catalog.Counterparties)
	|						OR EventParties.Contact = VALUE(Catalog.Counterparties.EmptyRef)
	|					THEN ""<Not specified>""
	|				ELSE PRESENTATION(EventParties.Contact)
	|			END AS CounterpartyPresentation,
	|			CASE
	|				WHEN Event.Subject = """"
	|					THEN ""<The subject is not specified>""
	|				ELSE Event.Subject
	|			END AS Subject,
	|			CASE
	|				WHEN (CAST(Event.Content AS String(255))) = """"
	|					THEN ""<Content is not specified>""
	|				ELSE CAST(Event.Content AS String(255))
	|			END AS Content,
	|			Event.Responsible AS Responsible,
	|			UNDEFINED AS ProductsAndServicesPresentation,
	|			UNDEFINED AS Comment,
	|			UNDEFINED AS CommentOfDocument,
	|			UNDEFINED AS CustomerPresentation,
	|			UNDEFINED AS Day,
	|			Event.EventBegin AS BeginTime,
	|			Event.EventEnding AS EndTime,
	|			UNDEFINED AS Closed
	|		FROM
	|			Document.Event AS Event
	|				LEFT JOIN Document.Event.Parties AS EventParties
	|				ON Event.Ref = EventParties.Ref
	|					AND (EventParties.LineNumber = 1)
	|		WHERE
	|			Event.Responsible IN(&EmployeesList)
	|			AND Event.DeletionMark = FALSE
	|			AND Event.EventBegin >= &BeginOfPeriod
	|			AND Event.EventBegin <= &EndOfPeriod
	|			AND (&State = VALUE(Catalog.EventStates.EmptyRef)
	|					OR Event.State = &State)
	|			AND (&EventType = VALUE(Enum.EventTypes.EmptyRef)
	|					OR Event.EventType = &EventType)
	|			AND (&Counterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|					OR EventParties.Contact = &Counterparty)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			0,
	|			1,
	|			CASE
	|				WHEN JobOrderWorks.Ref.State = VALUE(Catalog.EventStates.Completed)
	|					THEN 1
	|				ELSE 0
	|			END,
	|			CASE
	|				WHEN JobOrderWorks.Ref.State = VALUE(Catalog.EventStates.Completed)
	|					THEN 0
	|				ELSE 1
	|			END,
	|			CASE
	|				WHEN Not JobOrderWorks.Ref.State = VALUE(Catalog.EventStates.Completed)
	|						AND DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.EndTime) * 3600 + MINUTE(JobOrderWorks.EndTime) * 60 + Second(JobOrderWorks.EndTime)) > &DateOfSchedule
	|					THEN 1
	|				ELSE 0
	|			END,
	|			2,
	|			JobOrderWorks.Ref.Number,
	|			JobOrderWorks.LineNumber,
	|			JobOrderWorks.Ref,
	|			UNDEFINED,
	|			UNDEFINED,
	|			UNDEFINED,
	|			JobOrderWorks.Ref.Employee,
	|			PRESENTATION(JobOrderWorks.ProductsAndServices),
	|			CAST(JobOrderWorks.Comment AS String(255)),
	|			CAST(JobOrderWorks.Ref.Comment AS String(255)),
	|			PRESENTATION(JobOrderWorks.Customer),
	|			JobOrderWorks.Day,
	|			DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.BeginTime) * 3600 + MINUTE(JobOrderWorks.EndTime) * 60 + Second(JobOrderWorks.EndTime)),
	|			DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.EndTime) * 3600 + MINUTE(JobOrderWorks.EndTime) * 60 + Second(JobOrderWorks.EndTime)),
	|			CASE
	|				WHEN JobOrderWorks.Ref.State = VALUE(Catalog.EventStates.Completed)
	|					THEN TRUE
	|				ELSE FALSE
	|			END
	|		FROM
	|			Document.WorkOrder.Works AS JobOrderWorks
	|		WHERE
	|			JobOrderWorks.Ref.Posted = TRUE
	|			AND DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.BeginTime) * 3600 + MINUTE(JobOrderWorks.EndTime) * 60 + Second(JobOrderWorks.EndTime)) >= &BeginOfPeriod
	|			AND DATEADD(JobOrderWorks.Day, Second, hour(JobOrderWorks.EndTime) * 3600 + MINUTE(JobOrderWorks.EndTime) * 60 + Second(JobOrderWorks.EndTime)) <= &EndOfPeriod
	|			AND JobOrderWorks.Ref.Employee IN(&EmployeesList)
	|			AND (&Counterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|					OR JobOrderWorks.Customer = &Counterparty)
	|			AND (&State = VALUE(Catalog.EventStates.EmptyRef)
	|					OR JobOrderWorks.Ref.State = &State)
	|			AND (&EventType = VALUE(Enum.EventTypes.EmptyRef)
	|					OR &EventType = ""WorkOrder"")) AS NestedSelect
	|		ON (NestedSelect.Responsible = Employees.Ref)
	|WHERE
	|	Employees.Ref IN(&EmployeesList)
	|
	|ORDER BY
	|	Responsible,
	|	Order,
	|	BeginTime,
	|	EndTime,
	|	Number,
	|	LineNumber
	|TOTALS
	|	SUM(EventsQuantity),
	|	SUM(TasksQuantity),
	|	SUM(ClosedQuantity),
	|	SUM(InWorkQuantity),
	|	SUM(OverdueQuantity)
	|BY
	|	Responsible";
	
	User = Users.CurrentUser();
	Responsible = SmallBusinessReUse.GetValueByDefaultUser(User, "MainResponsible");
	EmployeeArray = New Array();
	
	If ValueIsFilled(FilterEmployee) Then
		EmployeeArray.Add(FilterEmployee);
	Else
		For Each RowEmployee IN EmployeesList Do
			If RowEmployee.Show Then
				EmployeeArray.Add(RowEmployee.Employee);
			EndIf;
		EndDo;
	EndIf;
	
	TemplateSchedule = DataProcessors.EmployeeCalendar.GetTemplate("WeekSchedule");
	
	If EmployeeArray.Count() = 0 Then
		TemplateArea = TemplateSchedule.GetArea("RowFilterIsEmpty");
		Schedule.Put(TemplateArea);
		Return;
	EndIf;
	
	Query.SetParameter("Responsible", Responsible);
	Query.SetParameter("DateOfSchedule", DateOfSchedule);
	Query.SetParameter("BeginOfPeriod", BegOfWeek(DateOfSchedule));
	Query.SetParameter("EndOfPeriod", EndOfWeek(DateOfSchedule));
	Query.SetParameter("BlankDate", '00010101');
	Query.SetParameter("EmployeesList", EmployeeArray);
	Query.SetParameter("Counterparty", FilterCounterparty);
	Query.SetParameter("EventType", StringIntoEnumeration(FilterEventType));
	Query.SetParameter("State", FilterState);
	
	QueryResultt = Query.ExecuteBatch();
	
	IterationByResponsible = QueryResultt[0].Select(QueryResultIteration.ByGroups);
	
	PictureIndex = 0;
	
	While IterationByResponsible.Next() Do
		
		TemplateArea = TemplateSchedule.GetArea("GroupName");
		TemplateArea.Parameters.Name = IterationByResponsible.ResponsiblePresentation;
		TemplateArea.Parameters.EventsQuantity = IterationByResponsible.EventsQuantity;
		TemplateArea.Parameters.TasksQuantity = IterationByResponsible.TasksQuantity;
		TemplateArea.Parameters.ClosedQuantity = IterationByResponsible.ClosedQuantity;
		TemplateArea.Parameters.InWorkQuantity = IterationByResponsible.InWorkQuantity;
		TemplateArea.Parameters.OverdueQuantity = IterationByResponsible.OverdueQuantity;
		Schedule.Put(TemplateArea);
		
		TitleLineNumber = Schedule.TableHeight;
		Schedule.StartRowGroup(, ?(IterationByResponsible.Responsible = Responsible, True, False));
		
		SelectionOfQueryResult = IterationByResponsible.Select();
		
		TemplateArea = TemplateSchedule.GetArea("RowScale");
		
		Schedule.Put(TemplateArea);
		
		For CurWeekday = 1 To 7 Do
			
			CurDate = BegOfWeek(DateOfSchedule) + CurWeekday * 86400 - 86400;
			If CurWeekday >= 1 AND CurWeekday <= 3 Then
				DayCoordinates = "R" + String(TitleLineNumber + 1) + "C" + String(CurWeekday * 2);
				DayTextCoordinates = "R" + String(TitleLineNumber + 2) + "C" + String(CurWeekday * 2);
			ElsIf CurWeekday >= 4 AND CurWeekday <= 6 Then
				DayCoordinates = "R" + String(TitleLineNumber + 3) + "C" + String((CurWeekday - 3) * 2);
				DayTextCoordinates = "R" + String(TitleLineNumber + 4) + "C" + String((CurWeekday - 3) * 2);
			Else
				DayCoordinates = "R" + String(TitleLineNumber + 5) + "C" + String((CurWeekday - 6) * 2);
				DayTextCoordinates = "R" + String(TitleLineNumber + 6) + "C" + String((CurWeekday - 6) * 2);
			EndIf;
			
			Schedule.Area(DayCoordinates).Text = Day(CurDate);
			
			DetailsStructure = New Structure;
			DetailsStructure.Insert("Period", CurDate);
			DetailsStructure.Insert("Responsible", IterationByResponsible.Responsible);
			
			Schedule.Area(DayTextCoordinates).Details = DetailsStructure;
			Schedule.Area(DayCoordinates).Details = DetailsStructure;
			
			SelectionOfQueryResult.Reset();
			ListOfEventsAndTasksOfDay = "";
			CtEventsAndJobs = 1;
			EventQuantityAndJobs = SelectionOfQueryResult.Count();
			
			While SelectionOfQueryResult.Next() Do
				
				If BegOfDay(CurDate) >= BegOfDay(SelectionOfQueryResult.BeginTime)
				   AND BegOfDay(CurDate) <= BegOfDay(SelectionOfQueryResult.BeginTime) Then
					
					If CtEventsAndJobs = 8 AND CtEventsAndJobs < EventQuantityAndJobs Then
						ListOfEventsAndTasksOfDay = ListOfEventsAndTasksOfDay + String(CtEventsAndJobs) + ". " + "Yet..." + Chars.LF;
					ElsIf CtEventsAndJobs < 8 Then
						
						If ValueIsFilled(SelectionOfQueryResult.Subject) Then
							Subject = SelectionOfQueryResult.Subject;
						ElsIf ValueIsFilled(SelectionOfQueryResult.ProductsAndServicesPresentation) Then
							Subject = SelectionOfQueryResult.ProductsAndServicesPresentation;
						ElsIf ValueIsFilled(SelectionOfQueryResult.Comment) Then
							Subject = SelectionOfQueryResult.Comment;
						ElsIf ValueIsFilled(SelectionOfQueryResult.CommentOfDocument) Then
							Subject = SelectionOfQueryResult.CommentOfDocument;
						Else
							Subject = "<Name is not specified>";
						EndIf;
						
						ListOfEventsAndTasksOfDay = ListOfEventsAndTasksOfDay + String(CtEventsAndJobs) + ". " + TrimAll(Subject) + Chars.LF;
					EndIf;
					
					CtEventsAndJobs = CtEventsAndJobs + 1;
					
				EndIf;
				
			EndDo;
			
			If ValueIsFilled(ListOfEventsAndTasksOfDay) Then
				Schedule.Area(DayTextCoordinates).Text = ListOfEventsAndTasksOfDay;
			EndIf;
			
			PictureIndex = PictureIndex + 1;
			
		EndDo;
		
		Schedule.EndRowGroup();
		
	EndDo;
	
EndProcedure // DisplayScheduleWeek()

// Procedure marks the completed task.
//
Procedure MarkCompletedJob(LineNumber, Completed, Color, Table)
	
	If Table = "MyCurrentDayTasks" Then
		
		Area = MyCurrentDayTasks.Area("R" + String(LineNumber) + "C2:R" + String(LineNumber + 1) + "C7");
		Area.TextColor = Color;
		
		Area = MyCurrentDayTasks.Area("R" + String(LineNumber) + "C5:R" + String(LineNumber + 1) + "C7");
		Area.Font = ?(Completed, New Font(Area.Font, 8, , , , , True), New Font(Area.Font, 8, , , , , False));
		
		Area = MyCurrentDayTasks.Area("R" + String(Area.Top) + "C3");
		Area.Font = ?(Completed, New Font(Area.Font, 8, , , , , True), New Font(Area.Font, 8, , , , , False));
		
		Area = MyCurrentDayTasks.Area("R" + String(Area.Top + 1) + "C3");
		Area.Font = ?(Completed, New Font(Area.Font, 8, , , , , True), New Font(Area.Font, 8, , , , , False));
		
	ElsIf Table = "Schedule" Then
		
		Area = Schedule.Area("R" + String(LineNumber) + "C3:R" + String(LineNumber + 1) + "C48");
		Area.TextColor = Color;
		
		Area = Schedule.Area("R" + String(LineNumber ) + "C5:R" + String(LineNumber + 1) + "C48");
		Area.Font = ?(Completed, New Font(Area.Font, 8, , , , , True), New Font(Area.Font, 8, , , , , False));
		
		Area = Schedule.Area("R" + String(Area.Top) + "C4");
		Area.Font = ?(Completed, New Font(Area.Font, 8, , , , , True), New Font(Area.Font, 8, , , , , False));
		
		Area = Schedule.Area("R" + String(Area.Top + 1) + "C4");
		Area.Font = ?(Completed, New Font(Area.Font, 8, , , , , True), New Font(Area.Font, 8, , , , , False));
		
	EndIf;
	
EndProcedure // MarkCompletedJob()

// Procedure marks the completed task on the server.
//
&AtServer
Procedure MarkCompletedJobAtServer(DocumentRef, Closed)
	
	DocumentObject = DocumentRef.GetObject();
	If DocumentObject.State = Catalogs.EventStates.Completed Then
		DocumentObject.State = Catalogs.EventStates.Planned;
	Else
		DocumentObject.State = Catalogs.EventStates.Completed;
	EndIf;
	DocumentObject.Write();
	
EndProcedure // MarkCompletedJobAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonUse.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	ImportFormSettings();
	
	For Each TSRow IN EmployeesList Do
		If TSRow.Show AND ValueIsFilled(TSRow.Employee) Then
			
			// Setting values for the fast selection - employee.
			Items.ScheduleFilterEmployee.ChoiceList.Add(TSRow.Employee);
			
		EndIf;
	EndDo;
	
	StyleColorOverdueJob = StyleColors.OverdueJob;
	StyleColorCompletedJob = StyleColors.CompletedJob;
	StyleColorPastEvent = StyleColors.PastEvent;
	
	User = Users.CurrentUser();
	Responsible = SmallBusinessReUse.GetValueByDefaultUser(User, "MainResponsible");
	
	DateOfSchedule = CurrentDate();
	
	RepresentContactsManager();
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	FillPresentationOfPeriod();
	
EndProcedure // OnOpen()

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose()
	
	SettingsStructure = New Structure;
	
	SettingsStructure.Insert("WorkScheduleDayPeriodCheck", RadioButton = "Day");
	SettingsStructure.Insert("WorkSchedulePeriodWeekCheck", RadioButton = "Week");
	SettingsStructure.Insert("WorkSchedulePeriodMonthCheck", RadioButton = "Month");
	
	SettingsStructure.Insert("Counterparty", FilterCounterparty);
	SettingsStructure.Insert("Employee", FilterEmployee);
	SettingsStructure.Insert("State", FilterState);
	SettingsStructure.Insert("EventType", FilterEventType);
	
	// Employees.
	DataStructure = New Structure;
	TabularSectionEmployeesList = New Array;
	For Each TSRow IN EmployeesList Do
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("Show", TSRow.Show);
		TabularSectionRow.Insert("Employee", TSRow.Employee);
		TabularSectionEmployeesList.Add(TabularSectionRow);
	EndDo;
	
	SettingsStructure.Insert("EmployeesList", TabularSectionEmployeesList);
	
	SaveFormSettings(SettingsStructure);
	
EndProcedure // OnClose()

// Procedure - event handler NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "EventChanged"
		OR EventName = "TaskChanged" Then
		
		// StandardSubsystems.PerformanceEstimation
		PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorEmplyeeCalendarGenerating");
		// StandardSubsystems.PerformanceEstimation
		
		RepresentContactsManager();
		
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - AddTaskSchedule click handler.
//
&AtClient
Procedure AddTaskSchedule(Command)
	
	Details = Schedule.CurrentArea.Details;
	FillValue = New Structure;
	
	If (RadioButton = "Month"
	  OR RadioButton = "Week")
		AND Details <> Undefined Then
		
		FillValue.Insert("BeginTime", BegOfDay(Details.Period));
		FillValue.Insert("EndTime", EndOfDay(Details.Period));
		
	ElsIf RadioButton = "Day" Then
		
		Left = Schedule.CurrentArea.Left;
		Right = Schedule.CurrentArea.Right;
		Top = Schedule.CurrentArea.Top;
		BeginTime = Undefined;
		EndTime = Undefined;
		
		For Ct = Left To Right Do
			CurArea = Schedule.Area(Top, Ct);
			If CurArea.Details <> Undefined Then
				If BeginTime = Undefined Then
					BeginTime = CurArea.Details.Period;
				EndIf;
				EndTime = CurArea.Details.Period + 1800;
			EndIf;
		EndDo;
		
		If BeginTime <> Undefined Then
			FillValue.Insert("BeginTime", BeginTime);
			FillValue.Insert("EndTime", EndTime);
		EndIf;
		
	EndIf;
	
	OpenForm("Document.WorkOrder.ObjectForm", FillValue);
	
EndProcedure // AddTaskSchedule()

// Procedure - AddEventSchedule click handler.
//
&AtClient
Procedure AddEventSchedule(Command)
	
	Details = Schedule.CurrentArea.Details;
	FillValue = New Structure;
	
	If (RadioButton = "Month"
	  OR RadioButton = "Week")
	   AND Details <> Undefined Then
		
		FillValue.Insert("EventBegin", BegOfDay(Details.Period));
		FillValue.Insert("EventEnding", EndOfDay(Details.Period));
		
	ElsIf RadioButton = "Day" Then
		
		Left = Schedule.CurrentArea.Left;
		Right = Schedule.CurrentArea.Right;
		Top = Schedule.CurrentArea.Top;
		BeginTime = Undefined;
		EndTime = Undefined;
		
		For Ct = Left To Right Do
			CurArea = Schedule.Area(Top, Ct);
			If CurArea.Details <> Undefined Then
				If BeginTime = Undefined Then
					BeginTime = CurArea.Details.Period;
				EndIf;
				EndTime = CurArea.Details.Period + 1800;
			EndIf;
		EndDo;
		
		If BeginTime <> Undefined Then
			FillValue.Insert("EventBegin", BeginTime);
			FillValue.Insert("EventEnding", EndTime);
		EndIf;
		
	EndIf;
	
	OpenForm("Document.Event.ObjectForm", New Structure("FillingValues", FillValue));
	
EndProcedure // AddEventSchedule()

// Procedure - AddTaskMyAgenda click handler.
//
&AtClient
Procedure AddTaskMyCurrentDayTasks(Command)
	
	OpenForm("Document.WorkOrder.ObjectForm", New Structure("Employee", Responsible), , , );
	
EndProcedure // AddTaskMyAgenda()

// Procedure - AddEventMyAgenda click handler.
//
&AtClient
Procedure AddEventMyCurrentDayTasks(Command)
	
	OpenForm("Document.Event.ObjectForm", New Structure("FillingValues", New Structure("Responsible", Responsible)), , , );
	
EndProcedure // AddEventMyAgenda()

// Procedure - WorkScheduleExtendPeriod click handler.
//
&AtClient
Procedure WorkScheduleExtendPeriod(Command)
	
	If RadioButton = "Month" Then
		DateOfSchedule = AddMonth(DateOfSchedule, 1);
	ElsIf RadioButton = "Week" Then
		DateOfSchedule = DateOfSchedule + 604800;
	ElsIf RadioButton = "Day" Then
		DateOfSchedule = DateOfSchedule + 86400;
	EndIf;
	
	FillPresentationOfPeriod();
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorEmplyeeCalendarGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	RepresentContactsManager();
	
EndProcedure // WorkScheduleExtendPeriod()

// Procedure - WorkScheduleShortenPeriod click handler.
//
&AtClient
Procedure WorkScheduleShortenPeriod(Command)
	
	If RadioButton = "Month" Then
		DateOfSchedule = AddMonth(DateOfSchedule, -1);
	ElsIf RadioButton = "Week" Then
		DateOfSchedule = DateOfSchedule - 604800;
	ElsIf RadioButton = "Day" Then
		DateOfSchedule = DateOfSchedule - 86400;
	EndIf;
	
	FillPresentationOfPeriod();
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorEmplyeeCalendarGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	RepresentContactsManager();
	
EndProcedure // WorkScheduleShortenPeriod()

// Procedure - handler of clicking the Refresh button.
//
&AtClient
Procedure Refresh(Command)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorEmplyeeCalendarGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	RepresentContactsManager();
	
EndProcedure // Refresh()

// Procedure - Settings click handler.
//
&AtClient
Procedure Settings(Command)
	
	ParametersStructure = New Structure();
	
	// Employees.
	TabularSectionEmployeesList = New Array;
	For Each TSRow IN EmployeesList Do
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("Show", TSRow.Show);
		TabularSectionRow.Insert("Employee", TSRow.Employee);
		TabularSectionEmployeesList.Add(TabularSectionRow);
	EndDo;
	
	ParametersStructure.Insert("EmployeesList", TabularSectionEmployeesList);
	
	Notification = New NotifyDescription("SettingsEnd",ThisForm);
	OpenForm("DataProcessor.EmployeeCalendar.Form.Settings", ParametersStructure,,,,,Notification);
	
EndProcedure // Settings()

&AtClient
Procedure SettingsEnd(ReturnStructure,Parameters) Export
	
	If TypeOf(ReturnStructure) = Type("Structure") AND ReturnStructure.WereMadeChanges Then
		
		EmployeesList.Clear();
		Items.ScheduleFilterEmployee.ChoiceList.Clear();
		FilterEmployee = Undefined;
		For Each ArrayRow IN  ReturnStructure.EmployeesList Do
			NewRow = EmployeesList.Add();
			FillPropertyValues(NewRow, ArrayRow);
			
			If ArrayRow.Show Then
				Items.ScheduleFilterEmployee.ChoiceList.Add(ArrayRow.Employee);
			EndIf;
			
		EndDo;
		
		// StandardSubsystems.PerformanceEstimation
		PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorEmplyeeCalendarGenerating");
		// StandardSubsystems.PerformanceEstimation
		
		RepresentContactsManager();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM ATTRIBUTE EVENT HANDLERS

// Procedure - Selection event handler of the MyAgenda attribute.
//
&AtClient
Procedure MyCurrentDayTasksSelection(Item, Area, StandardProcessing)
	
	If Area.Text = "" Then
		Area.Text = "";
		DocumentRef = MyCurrentDayTasks.Area("R" + String(Area.Top) + "C10").Details.DocumentRef;
		MarkCompletedJobAtServer(DocumentRef, True);
		MarkCompletedJob(Area.Top, True, StyleColorCompletedJob, "MyCurrentDayTasks");
	ElsIf Area.Text = "" Then
		Area.Text = "";
		DocumentRef = MyCurrentDayTasks.Area("R" + String(Area.Top) + "C10").Details.DocumentRef;
		DateTo = MyCurrentDayTasks.Area("R" + String(Area.Top) + "C10").Details.Date;
		MarkCompletedJobAtServer(DocumentRef, False);
		If DateTo < DateOfSchedule Then
			MarkCompletedJob(Area.Top, False, StyleColorOverdueJob, "MyCurrentDayTasks");
		Else
			MarkCompletedJob(Area.Top, False, New Color(), "MyCurrentDayTasks");
		EndIf;
	EndIf;
	
EndProcedure // MyAgendaSelection()

// Procedure - Selection event handler of the Schedule attribute.
//
&AtClient
Procedure ScheduleSelection(Item, Area, StandardProcessing)
	
	If Area.Text = "" Then
		Area.Text = "";
		DocumentRef = Schedule.Area("R" + String(Area.Top) + "C49").Details.DocumentRef;
		MarkCompletedJobAtServer(DocumentRef, True);
		MarkCompletedJob(Area.Top, True, StyleColorCompletedJob, "Schedule");
	ElsIf Area.Text = "" Then
		Area.Text = "";
		DocumentRef = Schedule.Area("R" + String(Area.Top) + "C49").Details.DocumentRef;
		DateTo = Schedule.Area("R" + String(Area.Top) + "C49").Details.Date;
		MarkCompletedJobAtServer(DocumentRef, False);
		If DateTo < DateOfSchedule Then
			MarkCompletedJob(Area.Top, False, StyleColorOverdueJob, "Schedule");
		Else
			MarkCompletedJob(Area.Top, False, New Color(), "Schedule");
		EndIf;
	EndIf;
	
EndProcedure // ScheduleSelection()

// Procedure - SelectionStart event handler of the WorksSchedulePeriodPresentation attribute.
//
&AtClient
Procedure WorkSchedulePeriodPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ParametersStructure = New Structure("CalendarDate", DateOfSchedule);
	Notification = New NotifyDescription("WorkSchedulesPeriodPresentationStartChoiceEnd",ThisForm);
	OpenForm("CommonForm.CalendarForm", ParametersStructure,,,,,Notification);
	
EndProcedure // WorkSchedulePeriodPresentationSelectionStart()

&AtClient
Procedure WorkSchedulesPeriodPresentationStartChoiceEnd(Result,Parameters) Export
	
	If ValueIsFilled(Result) Then
		
		DateOfSchedule = Result;
		FillPresentationOfPeriod();
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the ScheduleFilterEmployee attribute.
//
&AtClient
Procedure ScheduleFilterEmployeeOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorEmplyeeCalendarGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	RepresentContactsManager();
	
EndProcedure // ScheduleFilterEmployeeOnChange()

// Procedure - OnChange event handler of the MyAgendaFilterCounterparty attribute.
//
&AtClient
Procedure MyCurrentDayTasksCounterpartyFilterOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorEmplyeeCalendarGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	RepresentContactsManager();
	
EndProcedure // MyAgendaFilterCounterpartyOnChange()

// Procedure - OnChange event handler of the MyAgendaForFilterState attribute.
//
&AtClient
Procedure MyCurrentDayTasksFilterStatusOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorEmplyeeCalendarGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	RepresentContactsManager();
	
EndProcedure // MyAgendaFilterStatusOnChange()

// Procedure - OnChange event handler of the MyAgendaEventType attribute.
//
&AtClient
Procedure MyCurrentDayTasksEventTypeOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorEmplyeeCalendarGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	RepresentContactsManager();
	
EndProcedure // MyAgendaEventTypeOnChange()

// Procedure - OnChange event handler of the ScheduleFilterCounterparty attribute.
//
&AtClient
Procedure ScheduleFilterCounterpartyOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("Catalog.KeyOperations.DataProcessorEmplyeeCalendarGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	RepresentContactsManager();
	
EndProcedure // ScheduleFilterCounterpartyOnChange()

// Procedure - OnChange event handler of the ScheduleFilterState attribute.
//
&AtClient
Procedure ScheduleFilterStateOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorEmplyeeCalendarGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	RepresentContactsManager();
	
EndProcedure // ScheduleFilterStateOnChange()

// Procedure - OnChange event handler of the ScheduleFilterEventType attribute.
//
&AtClient
Procedure ScheduleFilterEventTypeOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorEmplyeeCalendarGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	RepresentContactsManager();
	
EndProcedure // ScheduleFilterEventTypeOnChange()

// Procedure - EncodingProcessor event handler of the Schedule attribute.
//
&AtClient
Procedure ScheduleDetailProcessing(Item, Details, StandardProcessing)
	
	StandardProcessing = False;
	
	If RadioButton = "Month"
	 OR RadioButton = "Week" Then
		
		DateOfSchedule = Details.Period;
		RadioButton = "Day";
		
		FillPresentationOfPeriod();
		
		// StandardSubsystems.PerformanceEstimation
		PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorEmplyeeCalendarGenerating");
		// StandardSubsystems.PerformanceEstimation
		
		RepresentContactsManager();
		
	ElsIf RadioButton = "Day" Then
		
		If Details.Property("DocumentRef")
		   AND TypeOf(Details.DocumentRef) = Type("DocumentRef.WorkOrder") Then
			OpenForm("Document.WorkOrder.ObjectForm", New Structure("Key", Details.DocumentRef), , , );
		ElsIf Details.Property("DocumentRef")
		        AND TypeOf(Details.DocumentRef) = Type("DocumentRef.Event") Then
			OpenForm("Document.Event.ObjectForm", New Structure("Key", Details.DocumentRef), , , );
		Else
			ChoiceList = New ValueList();
			ChoiceList.Add("Event", "Event");
			ChoiceList.Add("WorkOrder", "Work order");
			SelectedType = Undefined;

			ChoiceList.ShowChooseItem(New NotifyDescription("ScheduleEncodingProcessorEnd", ThisObject, New Structure("Details", Details)), "Select the type");
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ScheduleEncodingProcessorEnd(Result, AdditionalParameters) Export
	
	Details = AdditionalParameters.Details;
	
	SelectedType = Result;
	If SelectedType <> Undefined Then
		If SelectedType.Value = "Event" Then
			FillValue = New Structure;
			FillValue.Insert("Responsible", Details.Responsible);
			FillValue.Insert("EventBegin", Details.Period);
			FillValue.Insert("EventEnding", Details.Period + 1800);
			OpenForm("Document.Event.ObjectForm", New Structure("FillingValues", FillValue)); 
		Else
			FillValue = New Structure;
			FillValue.Insert("Employee", Details.Responsible);
			FillValue.Insert("BeginTime", Details.Period);
			FillValue.Insert("EndTime", Details.Period + 1800);
			OpenForm("Document.WorkOrder.ObjectForm", FillValue);
		EndIf;
	EndIf;
	
EndProcedure // ScheduleEncodingProcessor()

// Procedure - EncodingProcessor event handler of the MyAgenda attribute.
//
&AtClient
Procedure MyCurrentDayTasksDetailProcessing(Item, Details, StandardProcessing)
	
	StandardProcessing = False;
	
	If Details.Property("DocumentRef")
	   AND TypeOf(Details.DocumentRef) = Type("DocumentRef.WorkOrder") Then
		OpenForm("Document.WorkOrder.ObjectForm", New Structure("Key", Details.DocumentRef), , , );
	ElsIf Details.Property("DocumentRef")
		    AND TypeOf(Details.DocumentRef) = Type("DocumentRef.Event") Then
		OpenForm("Document.Event.ObjectForm", New Structure("Key", Details.DocumentRef), , , );
	EndIf;
	
EndProcedure // MyAgendaEncodingProcessor()


&AtClient
Procedure OpenTimeTrackingJournal(Command)
	OpenForm("DocumentJournal.TimeTrackingDocuments.ListForm", , , , );
EndProcedure


&AtClient
Procedure RadioButtonOnChange(Item)
	
	FillPresentationOfPeriod();
		
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorEmplyeeCalendarGenerating");
	// StandardSubsystems.PerformanceEstimation
	
	RepresentContactsManager();
	
EndProcedure

















