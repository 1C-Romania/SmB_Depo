// Form is called from:
// Document.Payroll.DocumentForm
// Document.Payroll.ListForm
// Document.PayrollSheet.DocumentForm
// Document.PayrollSheet.ListForm
// Document.CashPayment.DocumentForm
// Document.Timesheet.DocumentForm

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

// Procedure of idle data processor on date activation.
//
&AtClient
Procedure IdleProcessing()
	
	For Each SelectedDate IN Items.CalendarDate.SelectedDates Do
		
		CalendarDate = SelectedDate;
		
	EndDo;
	
	NotifyChoice(CalendarDate);
	
EndProcedure // IdleProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("CalendarDate", CalendarDate)
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - event handler OnActivateDate field CalendarDate.
//
&AtClient
Procedure CalendarDateOnActivateDate(Item)
	
	AttachIdleHandler("IdleProcessing", 0.2, True);
	
EndProcedure // CalendarDateOnActivateDate()









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
