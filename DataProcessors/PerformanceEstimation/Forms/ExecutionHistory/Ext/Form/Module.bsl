
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	KeyOperation = Parameters.HistorySettings.KeyOperation;
	StartDate = Parameters.HistorySettings.StartDate;
	EndDate = Parameters.HistorySettings.EndDate;
	Priority = KeyOperation.Priority;
	TargetTime = KeyOperation.TargetTime;
	
	Query = New Query;
	Query.SetParameter("KeyOperation", KeyOperation);
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", EndDate);
	
	Query.Text = 
	"SELECT
	|	TimeMeasurements.User AS User,
	|	TimeMeasurements.ExecutionTime AS Duration,
	|	TimeMeasurements.MeasurementStartDate AS EndTime
	|FROM
	|	InformationRegister.TimeMeasurements AS TimeMeasurements
	|WHERE
	|	TimeMeasurements.KeyOperation = &KeyOperation
	|	AND TimeMeasurements.MeasurementStartDate between &StartDate AND &EndDate
	|
	|ORDER BY
	|	EndTime";
	
	Selection = Query.Execute().Select();
	MeasurementsCountNumber = Selection.Count();
	MeasurementsCount = String(MeasurementsCountNumber) + ?(MeasurementsCountNumber < 100, " (NOT Enough)", "");
	
	While Selection.Next() Do
		
		HistoryRow = History.Add();
		FillPropertyValues(HistoryRow, Selection);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersHistory

// Prohibits editing key operation from DataProcessors
// form so. internal mechanisms can be damaged.
//
&AtClient
Procedure KeyOperationOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	
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
