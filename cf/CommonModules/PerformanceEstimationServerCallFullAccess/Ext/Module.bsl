////////////////////////////////////////////////////////////////////////////////
//  Methods associated with writing key operations duration measurements to the server and their further export.
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// The procedure writes a measurement array.
//
// Parameters:
//  Measurements - Item array of the Structure type.
//
// Returns:
//  Number - current value of measurements record period on the server in seconds.
Function ToFixDurationOfKeyOperations(Measurements) Export
	
	For Each KeyOperationMetering IN Measurements Do
		KeyOperationReference = KeyOperationMetering.Key;
		Buffer = KeyOperationMetering.Value;
		For Each DateData IN Buffer Do
			Data = DateData.Value;
			Duration = Data.Get("Duration");
			If Duration = Undefined Then
				// Unfinished measurement, it is too early to write it.
				Continue;
			EndIf;
			FixKeyOperationDuration(
				KeyOperationReference,
				Duration,
				DateData.Key,
				Data["EndDate"]);
		EndDo;
	EndDo;
	Return RecordPeriod();
EndFunction

// Current value of measurements record period on the server.
//
// Returns:
// Number - value in seconds. 
Function RecordPeriod() Export
	CurrentPeriod = Constants.PerformanceRatingRecordPeriod.Get();
	Return ?(CurrentPeriod >= 1, CurrentPeriod, 60);
EndFunction

// The procedure processes a scheduled job that exports data.
//
// Parameters:
//  ExportDirectories - Structure with a value of the Array type.
//
Procedure ExportPerformanceEstimation(ExportDirectories) Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	// If the system is disabled, the data will not be exported.
	If Not PerformanceEstimationServerCallReUse.ExecutePerformanceMeasurements() Then
	    Return;	
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	MAX(Measurements.DateRecords) AS MeasurementDate
	|FROM 
	|	InformationRegister.TimeMeasurements AS Measurements";
	Selection = Query.Execute().Select();
	If Selection.Next() AND Selection.MeasurementDate <> Null Then
		UpperBoundaryDatesOfMeasurements = Selection.MeasurementDate;
	Else 
		Return;	
	EndIf;
	
	Query = New Query;
	Query.SetParameter("MeasurementDate", UpperBoundaryDatesOfMeasurements);
	GenerateAPDEXCalculationRequest(Query);	
	APDEXSelection = Query.Execute().Select();
	
	MeasurementArrays = MeasurementsWithSeparationByKeyOperations(UpperBoundaryDatesOfMeasurements);
	ExportResults(ExportDirectories, APDEXSelection, MeasurementArrays);
	
EndProcedure

// Current date at server
//
// Returns:
// Date - Date and time on server.
Function DateAndTimeAtServer() Export
	Return CurrentDate();
EndFunction

// The function creates a new item of catalog "Key operations".
//
// Parameters:
//  KeyOperationName - String - name of the key operation.
//
// Returns:
//  CatalogRef.KeyOperations
//
Function CreateKeyOperation(KeyOperationName) Export
	
	BeginTransaction();
	
	Try
		Block = New DataLock;
		LockItem = Block.Add("Catalog.KeyOperations");
		LockItem.SetValue("Name", KeyOperationName);
		LockItem.Mode = DataLockMode.Exclusive;
		Block.Lock();
		
		Query = New Query;
		Query.Text = "SELECT TOP 1
		               |	KeyOperations.Ref AS Ref
		               |FROM
		               |	Catalog.KeyOperations AS KeyOperations
		               |WHERE
		               |	KeyOperations.Name = &Name
		               |
		               |ORDER BY
		               |	Ref";
		
		Query.SetParameter("Name", KeyOperationName);
		QueryResult = Query.Execute();
		If QueryResult.IsEmpty() Then
			Description = DecomposeStringByWords(KeyOperationName);
			
			NewItem = Catalogs.KeyOperations.CreateItem();
			NewItem.Name = KeyOperationName;
			NewItem.Description = Description;
			NewItem.Write();
			KeyOperationReference = NewItem.Ref;
		Else
			Selection = QueryResult.Select();
			Selection.Next();
			KeyOperationReference = Selection.Ref;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise
	EndTry;
	
	Return KeyOperationReference;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

///////////////////////////////////////////////////////////////////////////////
// Writing measurements of key operations duration.

// Procedure records a single measurement.
//
// Parameters:
//  KeyOperation - CatalogRef.KeyOperations - key
// 					operation or String - name of the key operation.
//  Duration - Number
//  KeyOperationStartDate - Date
Procedure FixKeyOperationDuration(
	KeyOperation, 
	Duration, 
	KeyOperationStartDate,
	EndDateCriticalOperation = Undefined
) Export
	
	If TypeOf(KeyOperation) = Type("String") Then
		KeyOperationReference = PerformanceEstimationServerCallReUse.GetKeyOperationByName(KeyOperation);
	Else
		KeyOperationReference = KeyOperation;
	EndIf;
	
	Record = InformationRegisters.TimeMeasurements.CreateRecordManager();
	Record.KeyOperation = KeyOperationReference;
	Record.MeasurementStartDate = ToUniversalTime(KeyOperationStartDate);
	Record.SessionNumber = InfobaseSessionNumber();
	
	Record.ExecutionTime = ?(Duration = 0, 0.001, Duration); // Duration is less than the timer permission.
	
	Record.DateRecords = ToUniversalTime(CurrentDate());
	If EndDateCriticalOperation <> Undefined Then
		Record.EndDate = ToUniversalTime(EndDateCriticalOperation);
	EndIf;
	Record.User = InfobaseUsers.CurrentUser();
	Record.DateRecordsLocal = CurrentSessionDate();
	
	Record.Write();
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Scheduled export job.

Function MeasurementsWithSeparationByKeyOperations(UpperBoundaryDatesOfMeasurements)
	Query = New Query;
	
	LastExportDate = Constants.LastPerformanceMeasurementUpdateDateUTC.Get();
	Constants.LastPerformanceMeasurementUpdateDateUTC.Set(UpperBoundaryDatesOfMeasurements);
	
	Query.SetParameter("LastExportDate", LastExportDate);	
	Query.SetParameter("UpperBoundaryDatesOfMeasurements", UpperBoundaryDatesOfMeasurements);	
	
	Query.Text = "SELECT
	|	Measurements.KeyOperation,
	|	Measurements.MeasurementStartDate,
	|	Measurements.ExecutionTime,
	|	Measurements.User,
	|	Measurements.DateRecords,
	|	  Measurements.SessionNumber 
	|	FROM
	|		InformationRegister.TimeMeasurements AS Measurements
	|	WHERE
	|		Measurements.DateRecords >= &LastExportDate AND
	|	      Measurements.DateRecords <= &UpperBoundaryDatesOfMeasurements
	|	ORDER BY
	|		Measurements.MeasurementStartDate";	
	ResultsSelection = Query.Execute().Unload(); // Select();
	Columns = ResultsSelection.Columns;	
	MeasurementsWithSeparation = New Map;
	KeyOperationColumnName = "KeyOperation";
	For Each ResultString IN ResultsSelection Do
		
		KeyOperationRow = String(ResultString[KeyOperationColumnName]);
		MeasurementsArrayByKeyOperation = MeasurementsWithSeparation.Get(KeyOperationRow);
		If MeasurementsArrayByKeyOperation = Undefined Then
			MeasurementsArrayByKeyOperation = New Array;
			MeasurementsWithSeparation.Insert(KeyOperationRow, MeasurementsArrayByKeyOperation);	
		EndIf;
		Metering = New Structure;
		For Each Column IN Columns Do							
			Metering.Insert(Column.Name, ResultString[Column.Name]);	
		EndDo;	
		
		MeasurementsArrayByKeyOperation.Add(Metering);
	EndDo;
	Return MeasurementsWithSeparation;
EndFunction	

// Generates a query to calculate APDEX index and sets values of required parameters.
//
// Parameters:
//  Query - Query, the procedure fills in a text and parameters of the passed query.
//
Procedure GenerateAPDEXCalculationRequest(Query)
	
	OverallSystemPerformance = PerformanceEstimationService.GetItemGeneralSystemPerformance();
	
	GettingMeasurements = 
	"SELECT
	|	&KeyOperation%KeyOperationNumber% AS KeyOperation,
	|	Measurements.ExecutionTime AS ExecutionTime
	|%NameOfTemporaryTable%
	|FROM
	|	(SELECT TOP 100
	|		Measurements.KeyOperation AS KeyOperation,
	|		Measurements.ExecutionTime AS ExecutionTime
	|	FROM
	|		InformationRegister.TimeMeasurements AS Measurements
	|	WHERE
	|		Measurements.MeasurementStartDate < &MeasurementDate
	|		AND Measurements.KeyOperation = &KeyOperation%KeyOperationNumber%
	|       AND Measurements.ExecutionTime > 0
	|       AND Measurements.ExecutionTime < &KeyOperation%KeyOperationNumber%_MaxTime
	|	
	|	ORDER BY
	|		Measurements.MeasurementStartDate DESC) AS Measurements";
	
	UnionAll =
	"
	|
	|UNION ALL
	|
	|";
	
	IndexBy = 
	"
	|
	|INDEX
	|	BY KeyOperation";
	
	TemporaryTablesSeparator = 
	"
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	EmptySelection = 
	"SELECT	
	|	VALUE(Catalog.KeyOperations.EmptyRef),
	|	0SELECT	
	|	VALUE(Catalog.KeyOperations.EmptyRef),
	|	0";
	
	QueryText = 
	"SELECT
	|	KeyOperations.Ref AS KeyOperation,
	|	KeyOperations.TargetTime AS TargetTime,
	|	KeyOperations.MinimumAllowedLevel AS AllowableLevel
	|INTO TU_KeyOperations
	|FROM
	|	Catalog.KeyOperations AS KeyOperations
	|WHERE
	|	KeyOperations.DeletionMark = FALSE
	|	AND KeyOperations.Ref <> &OverallSystemPerformance";
	
	QueryText = QueryText + IndexBy + TemporaryTablesSeparator;
	
	QueryKeyOperations = New Query;
	QueryKeyOperations.Text = "SELECT
	|	KeyOperations.Ref,
	|	KeyOperations.TargetTime
	|FROM
	|	Catalog.KeyOperations AS KeyOperations
	|WHERE
	|	KeyOperations.DeletionMark = FALSE
	|	AND KeyOperations.Ref <> &OverallSystemPerformance";
	
	QueryKeyOperations.SetParameter("OverallSystemPerformance", OverallSystemPerformance);
	Selection = QueryKeyOperations.Execute().Select();
	
	NoneOfKeyOperations = True;
	KeyOperationNumber = 1;
	While Selection.Next() Do
		
		Query.SetParameter("KeyOperation" + KeyOperationNumber, Selection.Ref);
		Query.SetParameter("KeyOperation" + KeyOperationNumber + "_MaxTime", 1000 * Selection.TargetTime);
		Temp = StrReplace(GettingMeasurements, "%KeyOperationNumber%", String(KeyOperationNumber));
		Temp = StrReplace(Temp, "%TemporaryTableName%", ?(KeyOperationNumber = 1, "INTO TT_Measurements", ""));
		QueryText = QueryText + Temp + UnionAll;
		
		KeyOperationNumber = KeyOperationNumber + 1;
		NoneOfKeyOperations = False;
	EndDo;
	
	// If there are no key operations, return an empty selection.
	If NoneOfKeyOperations Then
		Query.Text = "SELECT 1 WHERE 1 < 0;";
		Return;
	EndIf;
	
	QueryText = QueryText + EmptySelection + IndexBy + TemporaryTablesSeparator;
	
	QueryText = QueryText + 
	"SELECT
	|	TU_KeyOperations.KeyOperation AS KeyOperation,
	|	CASE
	|		WHEN
	|			// Key operation duration equals to zero (there are no operations which duration is greater than zero)
	|			Not 1 IN (
	|				SELECT TOP 1 
	|					1
	|				FROM
	|					TU_Measurements AS InternalMeasurements
	|				WHERE
	|					InternalMeasurements.KeyOperation = TU_KeyOperations.KeyOperation
	|					AND InternalMeasurements.ExecutionTime > 0
	|			)
	|			THEN -1
	|		ELSE CAST((SUM(CASE
	|						WHEN TU_Measurements.ExecutionTime <= TU_KeyOperations.TargetTime
	|							THEN 1
	|						ELSE 0
	|					END) + SUM(CASE
	|						WHEN TU_Measurements.ExecutionTime > TU_KeyOperations.TargetTime
	|								AND TU_Measurements.ExecutionTime <= TU_KeyOperations.TargetTime * 4
	|							THEN 1
	|						ELSE 0
	|					END) / 2) / SUM(1) AS NUMBER(6, 3))
	|	END AS CurrentAPDEX,
	|	CASE
	|		WHEN TU_KeyOperations.AllowableLevel = VALUE(Enum.PerformanceLevels.Perfect)
	|			THEN 1
	|		WHEN TU_KeyOperations.AllowableLevel = VALUE(Enum.PerformanceLevels.Excellent)
	|			THEN 0.94
	|		WHEN TU_KeyOperations.AllowableLevel = VALUE(Enum.PerformanceLevels.Good)
	|			THEN 0.85
	|		WHEN TU_KeyOperations.AllowableLevel = VALUE(Enum.PerformanceLevels.Satisfactorily)
	|			THEN 0.7
	|		WHEN TU_KeyOperations.AllowableLevel = VALUE(Enum.PerformanceLevels.Bad)
	|			THEN 0.5
	|	END AS MinimalAPDEX
	|FROM
	|	TU_KeyOperations AS TU_KeyOperations
	|		LEFT JOIN TU_Measurements AS TU_Measurements
	|		ON TU_KeyOperations.KeyOperation = TU_Measurements.KeyOperation
	|
	|GROUP BY
	|	TU_KeyOperations.KeyOperation,
	|	CASE
	|		WHEN TU_KeyOperations.AllowableLevel = VALUE(Enum.PerformanceLevels.Perfect)
	|			THEN 1
	|		WHEN TU_KeyOperations.AllowableLevel = VALUE(Enum.PerformanceLevels.Excellent)
	|			THEN 0.94
	|		WHEN TU_KeyOperations.AllowableLevel = VALUE(Enum.PerformanceLevels.Good)
	|			THEN 0.85
	|		WHEN TU_KeyOperations.AllowableLevel = VALUE(Enum.PerformanceLevels.Satisfactorily)
	|			THEN 0.7
	|		WHEN TU_KeyOperations.AllowableLevel = VALUE(Enum.PerformanceLevels.Bad)
	|			THEN 0.5
	|	END
	|
	|HAVING
	|	CASE
	|		WHEN
	|			// Key operation duration equals to zero (there are no operations which duration is greater than zero)
	|			Not 1 IN (
	|				SELECT TOP 1 
	|					1
	|				FROM
	|					TU_Measurements AS InternalMeasurements
	|				WHERE
	|					InternalMeasurements.KeyOperation = TU_KeyOperations.KeyOperation
	|					AND InternalMeasurements.ExecutionTime > 0
	|			)
	|			THEN -1
	|		ELSE CAST((SUM(CASE
	|						WHEN TU_Measurements.ExecutionTime <= TU_KeyOperations.TargetTime
	|							THEN 1
	|						ELSE 0
	|					END) + SUM(CASE
	|						WHEN TU_Measurements.ExecutionTime > TU_KeyOperations.TargetTime
	|								AND TU_Measurements.ExecutionTime <= TU_KeyOperations.TargetTime * 4
	|							THEN 1
	|						ELSE 0
	|					END) / 2) / SUM(1) AS NUMBER(6, 3))
	|	END >= 0";
	
	Query.SetParameter("OverallSystemPerformance", OverallSystemPerformance);
	Query.Text = QueryText;
	
EndProcedure

// Saves the results of APDEX calculations into file.
//
// Parameters:
//  ExportDirectories - Structure with a value of the Array type.
//  APDEXSelection - Query result.
//  MeasurementArrays - Structure with a value of the Array type.
Procedure ExportResults(ExportDirectories, APDEXSelection, MeasurementArrays)
	
	GeneratingDateFile = ToUniversalTime(CurrentSessionDate());
	TargetNamespace = "www.v8.1c.ru/ssl/performace-assessment/apdexExport";
	TempFileName = GetTempFileName(".xml");
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(TempFileName, "UTF-8");
	XMLWriter.WriteXMLDeclaration();
	XMLWriter.WriteStartElement("Performance", TargetNamespace);
	XMLWriter.WriteNamespaceMapping("prf", TargetNamespace);
	XMLWriter.WriteNamespaceMapping("xs", "http://www.w3.org/2001/XMLSchema");
	XMLWriter.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	
	XMLWriter.WriteAttribute("version", TargetNamespace, "1.0.0.0");
	XMLWriter.WriteAttribute("period", TargetNamespace, String(GeneratingDateFile));
	
	TypeKeyOperation = XDTOFactory.Type(TargetNamespace, "KeyOperation");
	TypeDimension = XDTOFactory.Type(TargetNamespace, "Measurement");
		    
	While APDEXSelection.Next() Do
		KeyOperation = XDTOFactory.Create(TypeKeyOperation);
		KeyOperationRow = String(APDEXSelection.KeyOperation);
		
		KeyOperation.name = KeyOperationRow;
		KeyOperation.currentApdexValue = APDEXSelection.CurrentAPDEX;
		KeyOperation.minimalApdexValue = ?(APDEXSelection.MinimalAPDEX = NULL, 0, APDEXSelection.MinimalAPDEX);
		
		KeyOperation.priority = APDEXSelection.KeyOperation.Priority;
		KeyOperation.targetValue = APDEXSelection.KeyOperation.TargetTime;
		KeyOperation.uid = String(APDEXSelection.KeyOperation.Ref.UUID());
		
		Measurements = MeasurementArrays.Get(KeyOperationRow);
		If Measurements <> Undefined Then
			For Each Metering IN Measurements Do
				MeasurementXML = XDTOFactory.Create(TypeDimension);
				MeasurementXML.value = Metering.ExecutionTime;
				If TypeOf(Metering.MeasurementStartDate) = Type("Number") Then
					MeasurementDate = Date("00010101") + Metering.MeasurementStartDate / 1000;
				Else
					MeasurementDate = Metering.MeasurementStartDate;
				EndIf;
				MeasurementXML.tUTC = MeasurementDate;
				MeasurementXML.userName = Metering.User;
				MeasurementXML.tSaveUTC = Metering.DateRecords;
				MeasurementXML.sessionNumber = Metering.SessionNumber;
				KeyOperation.measurement.Add(MeasurementXML);
			EndDo;
		EndIf;
		XDTOFactory.WriteXML(XMLWriter, KeyOperation);
		
	EndDo;
	XMLWriter.WriteEndElement();
	XMLWriter.Close();
	
	For Each KeyPerformDirectory IN ExportDirectories Do
		PerformDirectory = KeyPerformDirectory.Value;
		Perform = PerformDirectory[0];
		If Not Perform Then
			Continue;
		EndIf;
		
		ExportDirectory = PerformDirectory[1];
		Key = KeyPerformDirectory.Key;
		If Key = PerformanceEstimationClientServer.LocalExportDirectoryTaskKey() Then
			CreateDirectory(ExportDirectory);
		EndIf;
		
		FileCopy(TempFileName, ExportFileFullName(ExportDirectory, GeneratingDateFile, ".xml"));
	EndDo;
	DeleteFiles(TempFileName);
EndProcedure

// Generates a attachment file name for export.
//
// Parameters:
//  Directory - String, 
//  GenerationFileDate - Date, date and time of the measurement.
//  ExtensionWithDot - String that specifies the file extension as ".xxx". 
// Returns:
//  String - full path to the export file.
//
Function ExportFileFullName(Directory, GeneratingDateFile, ExtensionWithDot)
	
	Delimiter = ?(Upper(Left(Directory, 3)) = "FTP", "/", CommonUseClientServer.PathSeparator());
	Return RemoveSeparatorsOnFileNameEnd(Directory, Delimiter) + Delimiter + Format(GeneratingDateFile, "DF=""yyyy-MM-dd HH-mm-cc""") + ExtensionWithDot;

EndFunction

// Check whether a path has an end slash and if exists, delete it.
//
// Parameters:
//  FileName - String
//  Separator - String
Function RemoveSeparatorsOnFileNameEnd(Val FileName, Delimiter)
	
	LengthOfPath = StrLen(FileName);	
	If LengthOfPath = 0 Then
		Return FileName;
	EndIf;
	
	While LengthOfPath > 0 AND Right(FileName, 1) = Delimiter Do
		FileName = Left(FileName, LengthOfPath - 1);
		LengthOfPath = StrLen(FileName);
	EndDo;
	
	Return FileName;
	
EndFunction

// Divides a string with multiple grouped words into a string with separate words.
// A new word start is indicated by a character in the upper case.
//
// Parameters:
//  String                 - String - Text with delimiters;
//
// Returns:
//  String - String divided by words.
//
// Examples:
//  DecomposeStringByWords("OneTwoThree") - return string "One two three";
//
Function DecomposeStringByWords(Val String)
	
	ArrayOfWords = New Array;
	
	WordsPositions = New Array;
	For CharPosition = 1 To StrLen(String) Do
		CurSymbol = Mid(String, CharPosition, 1);
		If CurSymbol = Upper(CurSymbol) 
			AND (StringFunctionsClientServer.OnlyLatinInString(CurSymbol) 
				Or StringFunctionsClientServer.OnlyRomanInString(CurSymbol)) Then
			WordsPositions.Add(CharPosition);
		EndIf;
	EndDo;
	
	If WordsPositions.Count() > 0 Then
		PreviousPosition = 0;
		For Each Position IN WordsPositions Do
			If PreviousPosition > 0 Then
				Substring = Mid(String, PreviousPosition, Position - PreviousPosition);
				If Not IsBlankString(Substring) Then
					ArrayOfWords.Add(TrimAll(Substring));
				EndIf;
			EndIf;
			PreviousPosition = Position;
		EndDo;
		
		Substring = Mid(String, Position);
		If Not IsBlankString(Substring) Then
			ArrayOfWords.Add(TrimAll(Substring));
		EndIf;
	EndIf;
	
	For IndexOf = 1 To ArrayOfWords.UBound() Do
		ArrayOfWords[IndexOf] = Lower(ArrayOfWords[IndexOf]);
	EndDo;
	
	Result = StringFunctionsClientServer.RowFromArraySubrows(ArrayOfWords, " ");
	
	Return Result;
	
EndFunction

#EndRegion
