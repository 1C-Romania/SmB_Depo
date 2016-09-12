#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	If Not Users.InfobaseUserWithFullAccess(, True) Then
		ReadOnly = True;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		SetPresentationSchedule(ThisObject);
		MethodParameters = CommonUse.ValueToXMLString(New Array);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ID = Object.Ref.UUID();
	
	Schedule = CurrentObject.Schedule.Get();
	SetPresentationSchedule(ThisObject);
	
	MethodParameters = CommonUse.ValueToXMLString(CurrentObject.Parameters.Get());
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.Schedule = New ValueStorage(Schedule);
	CurrentObject.Parameters = New ValueStorage(CommonUse.ValueFromXMLString(MethodParameters));
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ID = Object.Ref.UUID();
	
EndProcedure

#EndRegion

#Region FormManagementItemsEventsHandlers

&AtClient
Procedure SchedulePresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	LockFormDataForEdit();
	
	If ValueIsFilled(Object.Pattern) Then
		ShowMessageBox(, NStr("en='For the jobs based on the templates, the schedule is specified in the template.';ru='Для заданий на основе шаблонов, расписание задается в шаблоне.'"));
		Return;
	EndIf;
	
	If Schedule = Undefined Then
		EditSchedule = New JobSchedule;
	Else
		EditSchedule = Schedule;
	EndIf;
	
	Dialog = New ScheduledJobDialog(EditSchedule);
	OnCloseNotifyDescription = New NotifyDescription("ChangeSchedule", ThisObject);
	Dialog.Show(OnCloseNotifyDescription);
	
EndProcedure

&AtClient
Procedure SchedulePresentationForClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	LockFormDataForEdit();
	
	Schedule = Undefined;
	Modified = True;
	SetPresentationSchedule(ThisObject);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ChangeSchedule(NewSchedule, AdditionalParameters) Export
	
	If NewSchedule = Undefined Then
		Return;
	EndIf;
	
	Schedule = NewSchedule;
	Modified = True;
	SetPresentationSchedule(ThisObject);
	
	ShowUserNotification(NStr("en='Replanning';ru='Перепланирование'"), , NStr("en='New schedule will be taken into account"
"when executing the next job';ru='Новое расписание будет учтено"
"при следующем выполнении задания'"));
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetPresentationSchedule(Val Form)
	
	Schedule = Form.Schedule;
	
	If Schedule <> Undefined Then
		Form.SchedulePresentation = String(Schedule);
	ElsIf ValueIsFilled(Form.Object.Pattern) Then
		Form.SchedulePresentation = NStr("en='<Set in template>';ru='<Задается в шаблоне>'");
	Else
		Form.SchedulePresentation = NStr("en='<Not defined>';ru='<Не задано>'");
	EndIf;
	
EndProcedure

#EndRegion





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
