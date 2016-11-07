#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Function forms the values table that will be displayed to a user.
//
// Returns:
//  ValueTable - summary table of values.
//
Function PerformanceIndicators() Export
	
	CalculationOptions = StructureForCalculationOfApdexParameters();
	
	StepNumber = 0;
	NumberOfSteps = 0;
	If Not FrequencyChart(StepNumber, NumberOfSteps) Then
		Return Undefined;
	EndIf;
	
	CalculationOptions.StepNumber = StepNumber;
	CalculationOptions.NumberOfSteps = NumberOfSteps;
	CalculationOptions.StartDate = StartDate;
	CalculationOptions.EndDate = EndDate;
	CalculationOptions.TableOfKeyOperations = Performance.Unload(, "KeyOperation, Priority, TargetTime");
	If Not ValueIsFilled(OverallSystemPerformance) Or Performance.Find(OverallSystemPerformance, "KeyOperation") = Undefined Then
		CalculationOptions.DisplayResults = False
	Else
		CalculationOptions.DisplayResults = True;
	EndIf;
	
	Return CalculateAPDEX(CalculationOptions);
	
EndFunction

// Function forms the query dynamically and receives APDEX.
//
// Parameters:
//  CalculationOptions - Structure see StructureForCalculationOfApdexParameters().
//
// Returns:
//  ValueTable - in the table the key operation
// and performance measure of the certain period of time return.
//
Function CalculateAPDEX(CalculationOptions) Export
	
	Query = New Query;
	Query.SetParameter("TableOfKeyOperations", CalculationOptions.TableOfKeyOperations);
	Query.SetParameter("BeginOfPeriod", CalculationOptions.StartDate);
	Query.SetParameter("EndOfPeriod", CalculationOptions.EndDate);
	Query.SetParameter("KeyOperationTotal", OverallSystemPerformance);
	
	Query.TempTablesManager = New TempTablesManager;
	Query.Text =
	"SELECT
	|	KeyOperations.KeyOperation AS KeyOperation,
	|	KeyOperations.Priority AS Priority,
	|	KeyOperations.TargetTime AS TargetTime
	|INTO KeyOperations
	|FROM
	|	&TableOfKeyOperations AS KeyOperations";
	Query.Execute();
	
	QueryText = 
	"SELECT
	|	KeyOperations.KeyOperation AS KeyOperation,
	|	KeyOperations.Priority AS Priority,
	|	KeyOperations.TargetTime AS TargetTime%Columns%
	|FROM
	|	KeyOperations AS KeyOperations
	|		LEFT JOIN InformationRegister.TimeMeasurements AS TimeMeasurements
	|		ON KeyOperations.KeyOperation = TimeMeasurements.KeyOperation
	|		AND TimeMeasurements.MeasurementStartDate between &BeginOfPeriod AND &EndOfPeriod
	|WHERE
	|	Not KeyOperations.KeyOperation = &KeyOperationTotal
	|
	|GROUP BY
	|	KeyOperations.KeyOperation,
	|	KeyOperations.Priority,
	|	KeyOperations.TargetTime
	|%Totals%";

	Expression = 
	"
	|	,CASE
	|		WHEN 
	|			// No records in the period of measurements on this key operation
	|			Not 1 IN (
	|				SELECT TOP 1
	|					1 
	|				FROM 
	|					InformationRegister.TimeMeasurements AS TimeMeasurementsExt
	|				WHERE
	|					TimeMeasurementsExt.KeyOperation = KeyOperations.KeyOperation 
	|					AND TimeMeasurementsExt.KeyOperation <> &KeyOperationTotal
	|					AND TimeMeasurementsExt.MeasurementStartDate between &BeginOfPeriod AND &EndOfPeriod
	|					AND TimeMeasurementsExt.MeasurementStartDate >= &BeginOfPeriod%Number% 
	|					AND TimeMeasurementsExt.MeasurementStartDate <= &EndOfPeriod%Number%
	|			) 
	|			THEN 0
	|
	|		ELSE (CAST((SUM(CASE
	|								WHEN TimeMeasurements.MeasurementStartDate >= &BeginOfPeriod%Number%
	|										AND TimeMeasurements.MeasurementStartDate <= &EndOfPeriod%Number%
	|									THEN CASE
	|											WHEN TimeMeasurements.ExecutionTime <= KeyOperations.TargetTime
	|												THEN 1
	|											ELSE 0
	|										END
	|								ELSE 0
	|							END) + SUM(CASE
	|								WHEN TimeMeasurements.MeasurementStartDate >= &BeginOfPeriod%Number%
	|										AND TimeMeasurements.MeasurementStartDate <= &EndOfPeriod%Number%
	|									THEN CASE
	|											WHEN TimeMeasurements.ExecutionTime > KeyOperations.TargetTime
	|													AND TimeMeasurements.ExecutionTime <= KeyOperations.TargetTime * 4
	|												THEN 1
	|											ELSE 0
	|										END
	|								ELSE 0
	|							END) / 2) / SUM(CASE
	|								WHEN TimeMeasurements.MeasurementStartDate >= &BeginOfPeriod%Number%
	|										AND TimeMeasurements.MeasurementStartDate <= &EndOfPeriod%Number%
	|									THEN 1
	|								ELSE 0
	|							END) + 0.001 AS NUMBER(6, 3)))
	|	END AS Performance%Number%";
	
	ExpressionForTotals = 
	"
	|	,SUM(CASE
	|			WHEN TimeMeasurements.MeasurementStartDate >= &BeginOfPeriod%Number%
	|					AND TimeMeasurements.MeasurementStartDate <= &EndOfPeriod%Number%
	|				THEN 1
	|			ELSE 0
	|		END) AS TimeTotal%Number%,
	|	SUM(CASE
	|			WHEN TimeMeasurements.MeasurementStartDate >= &BeginOfPeriod%Number%
	|					AND TimeMeasurements.MeasurementStartDate <= &EndOfPeriod%Number%
	|				THEN CASE
	|						WHEN TimeMeasurements.ExecutionTime <= KeyOperations.TargetTime
	|							THEN 1
	|						ELSE 0
	|					END
	|			ELSE 0
	|		END) AS TempT%Number%,
	|	SUM(CASE
	|			WHEN TimeMeasurements.MeasurementStartDate >= &BeginOfPeriod%Number%
	|					AND TimeMeasurements.MeasurementStartDate <= &EndOfPeriod%Number%
	|				THEN CASE
	|						WHEN TimeMeasurements.ExecutionTime > KeyOperations.TargetTime
	|								AND TimeMeasurements.ExecutionTime <= KeyOperations.TargetTime * 4
	|							THEN 1
	|						ELSE 0
	|					END
	|			ELSE 0
	|		END) AS TimeBetweenT4T%Number%";
	
	Total = 
	"
	|	MAX(TimeTotal%Number%)";
	
	OnGeneral = 
	"
	|	BY OVERALL";
	
	ColumnHeadings = New Array;
	Columns = "";
	Totals = "";
	BeginOfPeriod = CalculationOptions.StartDate;
	For CurStep = 0 To CalculationOptions.NumberOfSteps - 1 Do
		
		EndOfPeriod = ?(CurStep = CalculationOptions.NumberOfSteps - 1, CalculationOptions.EndDate, BeginOfPeriod + CalculationOptions.StepNumber - 1);
		
		StepIndex = Format(CurStep, "NZ=0; NG=0");
		Query.SetParameter("BeginOfPeriod" + StepIndex, BeginOfPeriod);
		Query.SetParameter("EndOfPeriod" + StepIndex, EndOfPeriod);
		
		ColumnHeadings.Add(ColumnsTitle(BeginOfPeriod));
		
		BeginOfPeriod = BeginOfPeriod + CalculationOptions.StepNumber;
		
		Columns = Columns + ?(CalculationOptions.DisplayResults, ExpressionForTotals, "") + Expression;
		Columns = StrReplace(Columns, "%Number%", StepIndex);
		
		If CalculationOptions.DisplayResults Then
			Totals = Totals + Total + ?(CurStep = CalculationOptions.NumberOfSteps - 1, "", ",");
			Totals = StrReplace(Totals, "%Number%", StepIndex);
		EndIf;
		
	EndDo;
	
	QueryText = StrReplace(QueryText, "%Columns%", Columns);
	QueryText = StrReplace(QueryText, "%Totals%", ?(CalculationOptions.DisplayResults, "TOTALS" + Totals, ""));
	QueryText = QueryText + ?(CalculationOptions.DisplayResults, OnGeneral, "");
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		Return New ValueTable;
	Else
		TableOfKeyOperations = Result.Unload();
		
		TableOfKeyOperations.Sort("Priority");
		If CalculationOptions.DisplayResults Then
			TableOfKeyOperations[0][0] = OverallSystemPerformance;
			CalculateTotalAPDEX(TableOfKeyOperations);
			// TableOfKeyOperations.Move(0, TableOfKeyOperations.Count() - 1);
		EndIf;
		
		ColumnIndex = 0;
		ArrayIndex = 0;
		While ColumnIndex <= TableOfKeyOperations.Columns.Count() - 1 Do
			
			KeyOperationsTableColumn = TableOfKeyOperations.Columns[ColumnIndex];
			If Left(KeyOperationsTableColumn.Name, 4) = "Temp" Then
				TableOfKeyOperations.Columns.Delete(KeyOperationsTableColumn);
				Continue;
			EndIf;
			
			If ColumnIndex < 3 Then
				ColumnIndex = ColumnIndex + 1;
				Continue;
			EndIf;
			KeyOperationsTableColumn.Title = ColumnHeadings[ArrayIndex];
			
			ArrayIndex = ArrayIndex + 1;
			ColumnIndex = ColumnIndex + 1;
			
		EndDo;
		
		Return TableOfKeyOperations;
	EndIf;
	
EndFunction

// Creates the parameters structure that is required for the calculation of APDEX.
//
// Returns:
//  Structure - 
//  	StepNumber - Number, step size is specified in seconds.
//  	NumberOfSteps - Number, quantity of steps in the period.
//  	StartDate - Date, date of starting measurements.
//  	EndDate - Date, date of ending measurements.
//  	TableOfKeyOperations - ValueTable,
//  		KeyOperation - CatalogRef.KeyOperations, a key operation.
//  		LineNumber - Number, the priority of the key operation.
//  		TargetTime - Number, target time of the key operation.
//  	DisplayResults - Boolean,
//  		True, calculate the final performance.
//  		False, do not calculate the final performance.
//
Function StructureForCalculationOfApdexParameters() Export
	
	Return New Structure(
		"StepNumber," +
		"NumberOfSteps," + 
		"StartDate," + 
		"EndDate," + 
		"KeyOperationsTable," + 
		"DisplayResults");
	
EndFunction

// Calculates the size and quantity of steps on a given interval.
//
// Parameters:
//  StepNumber [OUT] - Quantity, number of seconds that must be added to the start date in order to execute the next step.
//  StepsNumber [OUT] - Number, the quantity of steps in the given interval.
//
// Returns:
//  Boolean - 
//  	True, the parameters are calculated.
//  	False, parameters are not calculated.
//
Function FrequencyChart(StepNumber, NumberOfSteps) Export
	
	DifferenceOfTime = EndDate - StartDate + 1;
	
	If DifferenceOfTime <= 0 Then
		Return False;
	EndIf;
	
	// NumberOfSteps - an integer, rounded up.
	NumberOfSteps = 0;
	If Step = "Hour" Then
		StepNumber = 86400 / 24;
		NumberOfSteps = DifferenceOfTime / StepNumber;
		NumberOfSteps = Int(NumberOfSteps) + ?(NumberOfSteps - Int(NumberOfSteps) > 0, 1, 0);
	ElsIf Step = "Day" Then
		StepNumber = 86400;
		NumberOfSteps = DifferenceOfTime / StepNumber;
		NumberOfSteps = Int(NumberOfSteps) + ?(NumberOfSteps - Int(NumberOfSteps) > 0, 1, 0);
	ElsIf Step = "Week" Then
		StepNumber = 86400 * 7;
		NumberOfSteps = DifferenceOfTime / StepNumber;
		NumberOfSteps = Int(NumberOfSteps) + ?(NumberOfSteps - Int(NumberOfSteps) > 0, 1, 0);
	ElsIf Step = "Month" Then
		StepNumber = 86400 * 30;
		Temp = EndOfDay(StartDate);
		While Temp < EndDate Do
			Temp = AddMonth(Temp, 1);
			NumberOfSteps = NumberOfSteps + 1;
		EndDo;
	Else
		StepNumber = 0;
		NumberOfSteps = 1;
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure computes the APDEX resulting value.
//
// Parameters:
//  TableOfKeyOperations - ValueTable, query result that calculated the APDEX.
//
Procedure CalculateTotalAPDEX(TableOfKeyOperations)
	
	// Start with column 4, the first 3 are KeyOperation, Priority, TargetTime.
	IndexOfStartingColumn	= 3;
	IndexOfSummaryRows		= 0;
	PriorityColumnIndex	= 1;
	IndexOfLastRow	= TableOfKeyOperations.Count() - 1;
	IndexOfLastColumn	= TableOfKeyOperations.Columns.Count() - 1;
	MinimalPriority	= TableOfKeyOperations[IndexOfLastRow][PriorityColumnIndex];
	
	// Set the totals row to 0
	For Column = PriorityColumnIndex To IndexOfLastColumn Do
		If Not ValueIsFilled(TableOfKeyOperations[IndexOfSummaryRows][Column]) Then
			TableOfKeyOperations[IndexOfSummaryRows][Column] = 0;
		EndIf;
	EndDo;
	
	If MinimalPriority < 1 Then
		MessageText = NStr("en='Priorities are filled incorrectly. Calculation of APDEX total is impossible.';ru='Неверно заполнены приоритеты. Расчет итогового APDEX невозможен.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
		
	Column = IndexOfStartingColumn;
	While Column < IndexOfLastColumn Do
		NN = 0;
		TF = 0;
		HT = 0;
		
		MaximumNumberOfOperationsPerPeriod = TableOfKeyOperations[IndexOfSummaryRows][Column];
		
		// From 1 as 0 is totals row.
		For String = 1 To IndexOfLastRow Do
			
			PriorityOfCurrentOperation = TableOfKeyOperations[String][PriorityColumnIndex];
			NumberOfCurrentOperation = TableOfKeyOperations[String][Column];
			
			Factor = ?(NumberOfCurrentOperation = 0, 0, 
							MaximumNumberOfOperationsPerPeriod / NumberOfCurrentOperation * (1 - (PriorityOfCurrentOperation - 1) / MinimalPriority));
			
			TableOfKeyOperations[String][Column] = TableOfKeyOperations[String][Column] * Factor;
			TableOfKeyOperations[String][Column + 1] = TableOfKeyOperations[String][Column + 1] * Factor;
			TableOfKeyOperations[String][Column + 2] = TableOfKeyOperations[String][Column + 2] * Factor;
			
			NN = NN + TableOfKeyOperations[String][Column];
			TF = TF + TableOfKeyOperations[String][Column + 1];
			HT = HT + TableOfKeyOperations[String][Column + 2];
		EndDo;
		
		If NN = 0 Then
			ResultingAPDEX = 0;
		ElsIf TF = 0 AND HT = 0 AND NN <> 0 Then
			ResultingAPDEX = 0.001;
		Else
			ResultingAPDEX = (TF + HT / 2) / NN;
		EndIf;
		TableOfKeyOperations[IndexOfSummaryRows][Column + 3] = ResultingAPDEX;
		
		Column = Column + 4;
		
	EndDo;
	
EndProcedure


Function ColumnsTitle(BeginOfPeriod)
	
	If Step = "Hour" Then
		// Country is specified to output the zero in the front in order to replace 1:30:25 with 01:30:25.
		ColumnsTitle = String(Format(BeginOfPeriod, "L=en_UA; DLF=T"));
	Else
		ColumnsTitle = String(Format(BeginOfPeriod, "DF=dd.MM.yy"));
	EndIf;
	
	Return ColumnsTitle;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// OUTDATED PROCEDURES AND FUNCTIONS

// Outdated. You should use the StructureForCalculationOfApdexParameters function.
//
// Creates the parameters structure that is required for the calculation of APDEX.
//
// Returns:
//  Structure - 
//  	StepNumber - Number, step size is specified in seconds.
//  	NumberOfSteps - Number, quantity of steps in the period.
//  	StartDate - Date, date of starting measurements.
//  	EndDate - Date, date of ending measurements.
//  	TableOfKeyOperations - ValueTable,
//  		KeyOperation - CatalogRef.KeyOperations, a key operation.
//  		LineNumber - Number, the priority of the key operation.
//  		TargetTime - Number, target time of the key operation.
//  	DisplayResults - Boolean,
//  		True, calculate the final performance.
//  		False, do not calculate the final performance.
//
Function StructureParametersForCalculatingApdeksa() Export
	
	Return StructureForCalculationOfApdexParameters();
	
EndFunction

#EndRegion

#EndIf