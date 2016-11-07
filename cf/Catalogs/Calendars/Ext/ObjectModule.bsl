#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	If Not ConsiderHolidays Then
		// If the work timetable does not take into account the holidays, it is necessary to delete the holiday intervals.
		SchedulePreHolidayDay = WorkSchedule.FindRows(New Structure("DayNumber", 0));
		For Each TimetableString IN SchedulePreHolidayDay Do
			WorkSchedule.Delete(TimetableString);
		EndDo;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	// If the end date is not specified, it will be selected according to production calendar.
	EndDateFill = EndDate;
	
	DaysIncludedInSchedule = Catalogs.Calendars.DaysIncludedInSchedule(
									StartDate, 
									FillMethod, 
									FillTemplate, 
									EndDateFill,
									BusinessCalendar, 
									ConsiderHolidays, 
									BeginnigDate);
									
	Catalogs.Calendars.WriteScheduleDataToRegister(
		Ref, DaysIncludedInSchedule, StartDate, EndDateFill);
	
EndProcedure

#EndRegion

#EndIf