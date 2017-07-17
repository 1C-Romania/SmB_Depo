#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CheckPriority(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure CheckPriority(Cancel)
	
	If AdditionalProperties.Property(PerformanceEstimationClientServer.DontCheckPriority()) Or Priority = 0 Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Priority", Priority);
	Query.SetParameter("Ref", Ref);
	Query.Text = 
	"SELECT TOP 1
	|	KeyOperations.Ref AS Ref,
	|	KeyOperations.Description AS Description
	|FROM
	|	Catalog.KeyOperations AS KeyOperations
	|WHERE
	|	KeyOperations.Priority = &Priority
	|	AND KeyOperations.Ref <> &Ref";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		MessageText = NStr("en='Key operation with priority ""%1"" already exists (""%2"").';ru='Ключевая операция с приоритетом ""%1"" уже существует (%2).'");
		MessageText = StrReplace(MessageText, "%1", String(Priority));
		MessageText = StrReplace(MessageText, "%2", Selection.Description);
		PerformanceEstimationClientServer.WriteToEventLogMonitor(
			"Catalog.KeyOperations.ObjectModule.BeforeWrite",
			EventLogLevel.Error,
			MessageText);
		CommonUseClientServer.MessageToUser(MessageText);
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf