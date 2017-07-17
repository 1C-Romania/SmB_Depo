
////////////////////////////////////////////////////////////////////////////////
// MODULE VARIABLES

////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES 

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// The procedure manages the visible and availability values of the form items
//
//
Procedure SetEnabledAndVisibleAtServer()
	
	QueryText				= Object.Query;
	
	// Separated users can not edit the query
	EditQuery 		= Not Object.CustomQuery;
	Items.Query.Enabled = Not Object.CustomQuery;
	
	Items.Source.Enabled 				= Not Object.CustomQuery; 
	Items.DataFilterPeriods.Enabled	= Not Object.CustomQuery; 
	Items.Indicators.Enabled				= Not Object.CustomQuery; 
	Items.DataFilterSettingsFilter.Enabled	= Not Object.CustomQuery;
	Items.DataFilterSettingsFilterCommandBar.Enabled = Not Object.CustomQuery; 
	
EndProcedure // SetAvailabilityAndVisibleAtServer()

&AtClient
// Procedure is responsible for setting the
// current pages for the visible management depending on the attribute value of the SpecifyValueAtPayrollCalculation catalog item
//
Procedure SetVisibleCurrentPageAtClient()
	
	Items.VisibleManagement.CurrentPage = 
		?(Object.SpecifyValueAtPayrollCalculation, Items.VisibileOff, Items.VisibleOn);
	
EndProcedure // SetCurrentVisiblePageAtClient()

&AtClient
// The procedure adds a line to
// the query parameter table It is used when filling in items by the template
//
Procedure AddRowToQueryParametersTable(ParameterName, ParameterPresentation)
	
	NewQueryParameter 				 = Object.QueryParameters.Add();
	NewQueryParameter.Name 			 = ParameterName;
	NewQueryParameter.Presentation 	 = ParameterPresentation;
	
EndProcedure //AddLineToQueryParametersTable()

&AtClient
// Procedure fills attributes by the template.
//
Procedure FillByTemplate(PatternName)
	
	// Clearing
	Object.SourceName = "";
	Object.SourcePresentation = "";
	Object.Query = "";
	Object.DataFilterPeriods.Clear();
	Object.Indicators.Clear();
	Object.QueryParameters.Clear();
	
	// Filling
	If PatternName = "FixedAmount" Then
		
		// Fixed amount
		Object.Description 			= "Fixed amount";
		Object.ID 			= "FixedAmount";
		Object.CustomQuery		= False;
		Object.SpecifyValueAtPayrollCalculation = True;
		
	ElsIf PatternName = "NormDays" Then

		// Norm of days
		Object.Description 			= "Norm of days";
		Object.ID 			= "NormDays";
		Object.CustomQuery		= True;
		Object.SpecifyValueAtPayrollCalculation = False;
		
		AddRowToQueryParametersTable("Company", "Company");
		AddRowToQueryParametersTable("RegistrationPeriod", "Registration period");
		
		Object.Query = 
		"SELECT
		|	SUM(1) AS NormDays
		|FROM
		|	InformationRegister.CalendarSchedules AS CalendarSchedules
		|		INNER JOIN Catalog.Companies AS Companies
		|		ON CalendarSchedules.Calendar = Companies.BusinessCalendar
		|			AND (Companies.Ref = &Company)
		|WHERE
		|	CalendarSchedules.Year = YEAR(&RegistrationPeriod)
		|	AND CalendarSchedules.ScheduleDate between BEGINOFPERIOD(&RegistrationPeriod, MONTH) AND ENDOFPERIOD(&RegistrationPeriod, MONTH)
		|	AND CalendarSchedules.DayIncludedInSchedule";
		
	ElsIf PatternName = "NormHours" Then

		// Norm of hours
		Object.Description				= "Norm of hours";
		Object.ID 			= "NormHours";
		Object.CustomQuery		= True;
		Object.SpecifyValueAtPayrollCalculation = False;
		
		AddRowToQueryParametersTable("Company", "Company");
		AddRowToQueryParametersTable("RegistrationPeriod", "Registration period");
		
		Object.Query 			 = 
		"SELECT
		|	SUM(8) AS NormHours
		|FROM
		|	InformationRegister.CalendarSchedules AS CalendarSchedules
		|		INNER JOIN Catalog.Companies AS Companies
		|		ON CalendarSchedules.Calendar = Companies.BusinessCalendar
		|			AND (Companies.Ref = &Company)
		|WHERE
		|	CalendarSchedules.Year = YEAR(&RegistrationPeriod)
		|	AND CalendarSchedules.ScheduleDate between BEGINOFPERIOD(&RegistrationPeriod, MONTH) AND ENDOFPERIOD(&RegistrationPeriod, MONTH)
		|	AND CalendarSchedules.DayIncludedInSchedule";
		
	ElsIf PatternName = "DaysWorked" Then

		// Days worked
		Object.Description 		= "Days worked";
		Object.ID		= "DaysWorked";
		Object.CustomQuery	= False;
		Object.SpecifyValueAtPayrollCalculation = True;
		
	ElsIf PatternName = "HoursWorked" Then

		// Hours worked
		Object.Description 		= "Hours worked";
		Object.ID 		= "HoursWorked";
		Object.CustomQuery	= False;
		Object.SpecifyValueAtPayrollCalculation = True;
		
	ElsIf PatternName = "TariffRate" Then

		// Tariff rate
		Object.Description 		= "Tariff rate";
		Object.ID 		= "TariffRate";
		Object.CustomQuery	= False;
		Object.SpecifyValueAtPayrollCalculation = True;
		
	ElsIf PatternName = "HoursWorkedByJobs" Then

		// Worked by jobs
		Object.Description			= "Hours worked by jobs";
		Object.ID 		= "HoursWorkedByJobs";
		Object.CustomQuery	= True;
		Object.SpecifyValueAtPayrollCalculation = False;
		
		AddRowToQueryParametersTable("BeginOfPeriod", "Begin of period");
		AddRowToQueryParametersTable("EndOfPeriod", "End of period");
		AddRowToQueryParametersTable("Employee", "Employee");
		AddRowToQueryParametersTable("Company", "Company");
		AddRowToQueryParametersTable("Department", "Department");
		
		Object.Query =
		"SELECT
		|	Source.ImportActualTurnover
		|FROM
		|	AccumulationRegister.WorkOrders.Turnovers(&BeginOfPeriod, &EndOfPeriod, Auto, ) AS Source
		|WHERE
		|	Source.Employee = &Employee
		|	AND Source.StructuralUnit = &Department
		|	AND Source.Company = &Company";
	
	EndIf;
	
	#If ThinClient OR WebClient Then
		Items.QueryAssistant.Enabled = False;
	#Else
		Items.QueryAssistant.Enabled = Object.CustomQuery;
	#EndIf
	
	SetEnabledAndVisibleAtServer();
	
	SetVisibleCurrentPageAtClient();
	
EndProcedure //FillByTemplate()

&AtServer
// Function creates the condition string for the query
//
Function GetComparisonType(FieldName, FilterComparisonType)

    If FilterComparisonType = DataCompositionComparisonType.Equal  Then
		Return "Source." + FieldName + " = &" + StrReplace(FieldName, ".", "");

	ElsIf FilterComparisonType = DataCompositionComparisonType.Greater Then
		Return "Source." + FieldName + " > &" + StrReplace(FieldName, ".", "");
	
	ElsIf FilterComparisonType = DataCompositionComparisonType.GreaterOrEqual  Then
		Return "Source." + FieldName + " >= &" + StrReplace(FieldName, ".", "");
	
	ElsIf FilterComparisonType = DataCompositionComparisonType.InHierarchy 
		OR  FilterComparisonType = DataCompositionComparisonType.InListByHierarchy Then
		Return "Source." + FieldName + " IN HIERARCHY (&" + StrReplace(FieldName, ".", "") + ")";
	
	ElsIf FilterComparisonType = DataCompositionComparisonType.InList  Then
		Return "Source." + FieldName + " IN (&" + StrReplace(FieldName, ".", "") + ")";
	
	ElsIf FilterComparisonType = DataCompositionComparisonType.Less  Then
		Return "Source." + FieldName + " < &" + StrReplace(FieldName, ".", "");
	
	ElsIf FilterComparisonType = DataCompositionComparisonType.LessOrEqual  Then         
		Return "Source." + FieldName + " <= &" + StrReplace(FieldName, ".", "");
	
	ElsIf FilterComparisonType = DataCompositionComparisonType.NotInList  Then
		Return "NOT the source." + FieldName + " IN (&" + StrReplace(FieldName, ".", "") + ")";
	
	ElsIf FilterComparisonType = DataCompositionComparisonType.NotInHierarchy 
		OR FilterComparisonType = DataCompositionComparisonType.NotInListByHierarchy Then
		Return "NOT the source." + FieldName + " IN HIERARCHY (&" + StrReplace(FieldName, ".", "") + ")";
	
	ElsIf FilterComparisonType = DataCompositionComparisonType.NotEqual  Then
		Return "Source." + FieldName + " <> &" + StrReplace(FieldName, ".", "");
	
	EndIf; 

EndFunction // ()

&AtServer
// Procedure opens the query builder.
//
Procedure GenerateQueryFillParameters()

	FieldList = "";
	For Each Field IN Object.Indicators Do
		If Field.Use Then
			FieldList = FieldList + ?(FieldList = "", "", ",
 																	|     ") + "SUM(Source." + Field.Name + ")";
		EndIf; 
	EndDo; 

    ConditionsList = "";
	For Each FilterItem IN DataFilter.Settings.Filter.Items Do
		ConditionsList = ConditionsList + ?(ConditionsList = "", "", "
																	|	AND ") + GetComparisonType(FilterItem.LeftValue, FilterItem.ComparisonType);
	EndDo;

    QueryText = "SELECT 
					|	"+ FieldList + "
					|IN 
					|	"+ Object.SourceName + " AS the source" + ?(ConditionsList = "", "", "
					|WHERE 
					|	"+ ConditionsList);
    
	Object.Query = QueryText;

	Object.QueryParameters.Clear();

	For Each TSRow IN Object.DataFilterPeriods Do
		If Object.QueryParameters.FindRows(New Structure("Name", TSRow.BoundaryDateName)).Count() = 0 Then
			NewRow = Object.QueryParameters.Add();
			NewRow.Name = TSRow.BoundaryDateName;
			NewRow.Presentation = TSRow.BoundaryDateName;
			NewRow.Value = TSRow.Period;
		EndIf; 
	EndDo;
		 
	For Each FilterItem IN DataFilter.Settings.Filter.Items Do
		If Object.QueryParameters.FindRows(New Structure("Name", String(FilterItem.LeftValue))).Count() = 0 Then
			NewRow = Object.QueryParameters.Add();
			NewRow.Name = FilterItem.LeftValue;
			NewRow.Presentation = FilterItem.LeftValue;
			NewRow.ComparisonType = FilterItem.ComparisonType;
			NewRow.Value = FilterItem.RightValue;
		EndIf; 
	EndDo;
                                                                  
EndProcedure

&AtServer
// The function fills in the parameter list by the query text
//
Procedure FillParametersByQuery()

    Object.QueryParameters.Clear();
	QueryRow = Object.Query;
	Enter = Char(10);
    SubstringNumber = Find(QueryRow, "&");
	While SubstringNumber > 0 Do
		
		QueryRow = Right(QueryRow, (StrLen(QueryRow)-SubstringNumber));

		CommaNumber = Find(QueryRow, ",");
		SpaceNumber = Find(QueryRow, " ");
		EnterNumber	 = Find(QueryRow, Enter);
		BracketNumber	 = Find(QueryRow, ")");
		If CommaNumber = 0 AND SpaceNumber = 0 AND EnterNumber = 0 AND BracketNumber = 0 Then
        	ParameterName = QueryRow;
		Else
			If CommaNumber = 0 Then
				CommaNumber = 9000000;
			EndIf; 
	        If SpaceNumber = 0 Then
				SpaceNumber = 9000000;
			EndIf;
			If EnterNumber = 0 Then
				EnterNumber = 9000000;
			EndIf;
			If BracketNumber = 0 Then
				BracketNumber = 9000000;
			EndIf;
			EndOfParameter = min(CommaNumber, SpaceNumber, EnterNumber, BracketNumber);
			ParameterName = Left(QueryRow, EndOfParameter - 1);
        EndIf;

        If Object.QueryParameters.FindRows(New Structure("Name", ParameterName)).Count() = 0 Then
			NewRow = Object.QueryParameters.Add();
	        NewRow.Name = ParameterName;
	        NewRow.Presentation = ParameterName;
		EndIf;

	    SubstringNumber = Find(QueryRow, "&");
	EndDo;  	

EndProcedure // FillParametersByQuery()

&AtServer
// Function checks the query correctness.
//
Function QueryCorrect()
    
	Try
		QueryBuilder = New QueryBuilder;
		QueryBuilder.Text = Object.Query;
		QueryBuilder.FillSettings();
        If QueryBuilder.Dimensions.Count() > 0 Then
		    Message = New UserMessage();
			Message.Text = NStr("en='Query should not contain totals.';ru='Запрос не должен содержать итоги!'");
			Message.Message();			
			Return False;
		EndIf; 
		If QueryBuilder.SelectedFields.Count() > 1 Then
		    Message = New UserMessage();
			Message.Text = NStr("en='The request cannot contain more than one indicator.';ru='Запрос должен содержать не более одного показателя!'");
			Message.Message();			
			Return False;
		EndIf;
		Return True;
	Except
        Return False;
	EndTry;	

EndFunction // CheckRequest()

&AtClient
// Procedure creates the calculation parameter identifier.
//    
Procedure GetID(StrDescription)
     
	Separators     =  " .,+,-,/,*,?,=,<,>May ,()%!@#$%&amp;*&quot;:;{}[]?()\|/`~'^";
	 
	Object.ID = "";
	WasSpecCharacter = False;
	For CharacterNum = 1 To StrLen(StrDescription) Do
	  	Char = Mid(StrDescription,CharacterNum,1);
		If Find(Separators, Char) <> 0 Then
		   WasSpecCharacter = True;
		ElsIf WasSpecCharacter Then
		   WasSpecCharacter = False;
		   Object.ID = Object.ID + Upper(Char);
		Else
		   Object.ID = Object.ID + Char;          
		EndIf;

	EndDo;
          
EndProcedure //GetID

&AtServer
// The function checks the duplication of the indicator ID to IB.
//     
Function CheckForIDDuplication(Cancel)

	Query = New Query(
	"SELECT
	|     CalculationsParameters.ID
	|FROM
	|     Catalog.CalculationsParameters AS CalculationsParameters
	|WHERE
	|     CalculationsParameters.ID = &ID
	|     AND CalculationsParameters.Ref <> &Ref");
	 
	Query.SetParameter("ID", Object.ID);
	Query.SetParameter("Ref", Object.Ref);
	 
	Selection = Query.Execute().Select();
	Cancel = Selection.Count() > 0;
	 
	If Cancel Then
	
	  	Message = New UserMessage();
		Message.Text = NStr("en='The calculation parameter with the same ID already exists.';ru='Параметр расчета с таким идентификатором уже существует!'");
		Message.Message();
		
	EndIf;
	 
	Return Cancel;
     
EndFunction // IDDuplicationCheck()

&AtServer
// Function checks if the indicator is selected.
//
Function CheckForIndicatorChoice()

	For Each TSRow IN Object.Indicators Do
		If TSRow.Use Then
			Return False;
		EndIf; 
	EndDo; 
	 
	Message = New UserMessage();
	Message.Text = NStr("en='Indicator is not selected.';ru='Не выбран показатель!'");
	Message.Message();

	Return True;
     
EndFunction // CheckIndicatorSelection()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

&AtServer
// The procedure fills in indicators and periods of the register data filter.
//
Procedure FillIndicatorsAndSourceDataFilterPeriods()

	SourceByMetadataKind = Left(Object.SourceName, Find(Object.SourceName,".")-1);

	SourceTable = StrReplace(Object.SourceName, SourceByMetadataKind + "." , "");
	
    Periodical = True;
	Ct = Find(SourceTable,".");
	
	If Ct > 0 Then	
		SourceByMetadataName = Left(SourceTable, Ct - 1);

	ElsIf Find(Object.SourcePresentation, "movement:") > 0 Then
		SourceByMetadataName = SourceTable;

	Else
		SourceByMetadataName = SourceTable;
		Periodical = False;  
			
	EndIf;

    MetadataSource = Metadata[StrReplace(SourceByMetadataKind, "Register", "Registers")][SourceByMetadataName];

    For Each Resource IN MetadataSource.Resources Do

		// 1. Accumulation register.
		If Find(Object.SourceName, "AccumulationRegister")>0 Then

			If Find(Object.SourcePresentation,": turnovers")  Then

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation 	= Resource.Synonym + ": turnover";
				NewIndicator.Name 			= Resource.Name + "Turnover";
				NewIndicator.Use 	= False;

			ElsIf Find(Object.SourcePresentation, ": balance and turnovers") > 0 Then

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation 	= Resource.Synonym + ": initial balance";
				NewIndicator.Name 			= Resource.Name + "OpeningBalance";
				NewIndicator.Use 	= False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation 	= Resource.Synonym + ": receipt";
				NewIndicator.Name 			= Resource.Name + "Receipt";
				NewIndicator.Use 	= False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation 	= Resource.Synonym + ": turnover";
				NewIndicator.Name 			= Resource.Name + "Turnover";
				NewIndicator.Use 	= False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation 	= Resource.Synonym + ": expense";
				NewIndicator.Name				= Resource.Name + "Expense";
				NewIndicator.Use	= False;
                 
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation	= Resource.Synonym + ": final balance";
				NewIndicator.Name				= Resource.Name + "ClosingBalance";
				NewIndicator.Use	= False;

			ElsIf Find(Object.SourcePresentation, ": balance") > 0 Then

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation	= Resource.Synonym + ": balance";
				NewIndicator.Name				= Resource.Name + "Balance";
				NewIndicator.Use	= False;
				
			ElsIf Find(Object.SourcePresentation, "register records: receipt") > 0 Then
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation	= Resource.Synonym + ": receipt";
				NewIndicator.Name				= Resource.Name;
				NewIndicator.Use	= False;
				
			ElsIf Find(Object.SourcePresentation, "flow: expense") > 0 Then
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation 	= Resource.Synonym + ": expense";
				NewIndicator.Name				= Resource.Name;
				NewIndicator.Use	= False;
				
			ElsIf Find(Object.SourcePresentation, "flow: turnover") > 0 Then
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation 	= Resource.Synonym + ": turnover";
				NewIndicator.Name				= Resource.Name;
				NewIndicator.Use	= False;
							
			EndIf;

		// 2. Data register.
		ElsIf Find(Object.SourceName, "InformationRegister") > 0 Then

			ResourceTypes = Resource.Type.Types();

			If ResourceTypes.Count() = 1 AND ResourceTypes[0] = Type("Number") Then

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation	= Resource.Synonym;
				NewIndicator.Name				= Resource.Name;
				NewIndicator.Use	= False;

			EndIf;

		// 3. Accounting register.	
        ElsIf Find(Object.SourceName,"AccountingRegister") > 0 Then

			If Find(Object.SourcePresentation,": turnovers with correspondence") > 0  Then
											
				If Not Resource.AccountingFlag = Undefined Then
					
					NewIndicator = Object.Indicators.Add();
					NewIndicator.Presentation = Resource.Name + ": Dr turnover";
					NewIndicator.Name = Resource.Name + "TurnoverDr";
					NewIndicator.Use = False;
					
					NewIndicator = Object.Indicators.Add();
					NewIndicator.Presentation = Resource.Name + ": Cr turnover";
					NewIndicator.Name = Resource.Name + "TurnoverCr";
					NewIndicator.Use = False;
					
				Else
					
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": turnover";
				NewIndicator.Name = Resource.Name + "Turnover";
				NewIndicator.Use = False;
		
				EndIf;

			ElsIf Find(Object.SourcePresentation,": balance and turnovers") > 0 Then

                NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": final balance";
				NewIndicator.Name = Resource.Name + "ClosingBalance";
				NewIndicator.Use = False;

                NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": Dr final balance";
				NewIndicator.Name = Resource.Name + "ClosingBalanceDr";
				NewIndicator.Use = False;

                NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": Cr final balance";
				NewIndicator.Name = Resource.Name + "ClosingBalanceCr";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": Dr final detailed balance";
				NewIndicator.Name = Resource.Name + "ClosingSplittedBalanceDr";
				NewIndicator.Use = False;

                NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": Cr final detailed balance";
				NewIndicator.Name = Resource.Name + "ClosingSplittedBalanceCr";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": initial balance";
				NewIndicator.Name = Resource.Name + "OpeningBalance";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": Dr initial balance";
				NewIndicator.Name = Resource.Name + "OpeningBalanceDr";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": Cr initial balance";
				NewIndicator.Name = Resource.Name + "OpeningBalanceCt";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name+": Dr initial detailed balance";
				NewIndicator.Name = Resource.Name + "OpeningSplittedBalanceDr";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": Cr initial detailed balance";
				NewIndicator.Name = Resource.Name + "OpeningSplittedBalanceCr";
				NewIndicator.Use = False;
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": turnover";
				NewIndicator.Name = Resource.Name + "Turnover";
				NewIndicator.Use = False;
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": Dr turnover";
				NewIndicator.Name = Resource.Name + "TurnoverDr";
				NewIndicator.Use = False;
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": Cr turnover";
				NewIndicator.Name = Resource.Name + "TurnoverCr";
				NewIndicator.Use = False;
                            			
			ElsIf Find(Object.SourcePresentation,": balance") > 0 Then

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": balance";
				NewIndicator.Name = Resource.Name+"Balance";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": Dr balance";
				NewIndicator.Name = Resource.Name + "BalanceDr";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": Cr balance";
				NewIndicator.Name = Resource.Name + "BalanceCr";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": Dr detailed balance";
				NewIndicator.Name = Resource.Name + "SplittedBalanceDr";
				NewIndicator.Use = False;

				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": Cr detailed balance";
				NewIndicator.Name = Resource.Name + "SplittedBalanceCr";
				NewIndicator.Use = False;
				
			ElsIf Find(Object.SourcePresentation,": turnovers") > 0 Then
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": turnover";
				NewIndicator.Name = Resource.Name + "Turnover";
				NewIndicator.Use = False;
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": Dr turnover";
				NewIndicator.Name = Resource.Name + "TurnoverDr";
				NewIndicator.Use = False;
				
				NewIndicator = Object.Indicators.Add();
				NewIndicator.Presentation = Resource.Name + ": Cr turnover";
				NewIndicator.Name = Resource.Name + "TurnoverCr";
				NewIndicator.Use = False;
				
			ElsIf Find(Object.SourcePresentation,": register records with dimension") > 0 Then
				
				If Not Resource.AccountingFlag = Undefined Then
					
					NewIndicator = Object.Indicators.Add();
					NewIndicator.Presentation = Resource.Name + ": Dr";
					NewIndicator.Name = Resource.Name + "Dr";
					NewIndicator.Use = False;
					
					NewIndicator = Object.Indicators.Add();
					NewIndicator.Presentation = Resource.Name + ": Cr";
					NewIndicator.Name = Resource.Name + "Cr";
					NewIndicator.Use = False;
					
				Else
					
					NewIndicator = Object.Indicators.Add();
					NewIndicator.Presentation = Resource.Name;
					NewIndicator.Name = Resource.Name;
					NewIndicator.Use = False;
		
				EndIf;
				
			EndIf;
        			
      	EndIf;
        
	EndDo;

	If Object.Indicators.Count() > 0 Then
		Object.Indicators[0].Use = True;
	EndIf; 

    // 4. Data filter periods.
	If Periodical Then

		If Find(Object.SourcePresentation, "Turnovers") > 0 OR Find(Object.SourcePresentation, "movement:") > 0 Then

			FilterNewBoundary = Object.DataFilterPeriods.Add();
			FilterNewBoundary.BoundaryDateName			= "BeginOfPeriod";
			FilterNewBoundary.BoundaryDatePresentation	= "Data filter beginning date";
			FilterNewBoundary.PeriodBoundaryType		= Enums.PeriodRangeTypes.BeginOfPeriod;

			FilterNewBoundary = Object.DataFilterPeriods.Add();
			FilterNewBoundary.BoundaryDateName			= "EndOfPeriod";
			FilterNewBoundary.BoundaryDatePresentation = "Data filter end date";
			FilterNewBoundary.PeriodBoundaryType		= Enums.PeriodRangeTypes.EndOfPeriod;

		Else

			FilterNewBoundary = Object.DataFilterPeriods.Add();
			FilterNewBoundary.BoundaryDateName 			= "PointInTime";
			FilterNewBoundary.BoundaryDatePresentation	= "Value date";
			FilterNewBoundary.PeriodBoundaryType		= Enums.PeriodRangeTypes.BeginOfPeriod;

		EndIf;

	EndIf;
    	
	// 5. Filter.
	InitializeFilter(MetadataSource);
  	 
EndProcedure // FillSourceDataFilterPeriodsAndIndicators()

&AtServer
// Procedure initiates the data source filter.
//
Procedure InitializeFilter(MetadataSource)

	CompositionSchema = New DataCompositionSchema();		
		
	Source = CompositionSchema.DataSources.Add();
	Source.Name = "Source1";
	Source.ConnectionString="";
	Source.DataSourceType = "local";
	
	QueryText = "SELECT";
	ValFlag = False;
	For Each Dimension IN MetadataSource.Dimensions Do

		If ValFlag Then

			QueryText = 	QueryText + ",
							| " + Dimension.Name;

		Else
	
			QueryText = 	QueryText + "
							| " + Dimension.Name;

		EndIf;
	
		ValFlag = True;	
	
	EndDo;

	QueryText = 	QueryText + " 
					|IN " + Object.SourceName;
	
	DataSet = CompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Query = QueryText;
	DataSet.Name = "Query";
	DataSet.DataSource = "Source1";
	
	TemporaryStorageAddress = PutToTempStorage(CompositionSchema, UUID);
	SettingsSource = New DataCompositionAvailableSettingsSource(TemporaryStorageAddress);	
	DataFilter.Initialize(SettingsSource);

EndProcedure // InitiateFilter()

// Procedure sets filter.
//
Procedure SetFilter()

	If Not Object.CustomQuery Then

		DataFilter.Settings.Filter.Items.Clear();

		// Fill in a filter.
		For Each ParameterString IN Object.QueryParameters Do

			If ParameterString.Name <> "PointInTime"
				AND ParameterString.Name <> "BeginOfPeriod"
				AND ParameterString.Name <> "EndOfPeriod" Then

				FilterItem = DataFilter.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
				FilterItem.LeftValue = New DataCompositionField(ParameterString.Name);
				If ParameterString.ComparisonType = "" Then
					FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
				Else
				    FilterItem.ComparisonType = DataCompositionComparisonType[StrReplace(ParameterString.ComparisonType," ","")];
				EndIf; 
				FilterItem.RightValue = ParameterString.Value;

			EndIf;

		EndDo;			
	
	EndIf;

EndProcedure // SpecifyFilter()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		Object.SpecifyValueAtPayrollCalculation = True;
		
	EndIf;
	
	If ValueIsFilled(Object.Ref) AND ValueIsFilled(Object.SourceName) Then

		SourceByMetadataKind = Left(Object.SourceName, Find(Object.SourceName,".")-1);

		SourceTable = StrReplace(Object.SourceName, SourceByMetadataKind + "." , "");
		
		Periodical = True;
		Ct = Find(SourceTable,".");
		
		If Ct > 0 Then	
			SourceByMetadataName = Left(SourceTable, Ct - 1);

		ElsIf Find(Object.SourcePresentation, "movement:") > 0 Then
			SourceByMetadataName = SourceTable;

		Else
			SourceByMetadataName = SourceTable;
			Periodical = False;  
				
		EndIf;

		MetadataSource = Metadata[StrReplace(SourceByMetadataKind, "Register", "Registers")][SourceByMetadataName];

		InitializeFilter(MetadataSource);

		SetFilter();

	EndIf;
	
	SetEnabledAndVisibleAtServer();
	
EndProcedure // OnCreateAtServer()

&AtClient
// Procedure - OnOpen form event handler
//
Procedure OnOpen(Cancel)
	
	#If ThinClient OR WebClient Then
		Items.QueryAssistant.Enabled = False;
	#Else
		Items.QueryAssistant.Enabled = Object.CustomQuery;
	#EndIf
	
	SetVisibleCurrentPageAtClient();
	
EndProcedure

&AtServer
// Procedure - event handler BeforeWriteAtServer form.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CheckForIDDuplication(Cancel);
	If Cancel Then
		Return;
	EndIf;
    
    If Not Object.SpecifyValueAtPayrollCalculation AND Not Object.CustomQuery Then

        Cancel = CheckForIndicatorChoice();
 		If Cancel Then
			Return;
		EndIf;
	
		GenerateQueryFillParameters();

	ElsIf Not Object.SpecifyValueAtPayrollCalculation AND Object.CustomQuery Then

        Cancel = Not QueryCorrect();

	EndIf;   
	
EndProcedure // BeforeWriteAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure - SelectionStart event handler of the Source field.
//
Procedure SourceStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	Notification = New NotifyDescription("SourceStartChoiceEnd",ThisForm);
	OpenForm("Catalog.CalculationsParameters.Form.SourceChoiceForm",,,,,,Notification);
	
EndProcedure // SourceSelectionStart()

&AtClient
Procedure SourceStartChoiceEnd(ChoiceStructure,Parameters) Export
	
	If ChoiceStructure = Undefined Then 
		Return;
	EndIf;
	
	Object.SourceName = ChoiceStructure.Source;
	Object.SourcePresentation = ChoiceStructure.FieldPresentation;
	
	Object.Indicators.Clear();
	Object.DataFilterPeriods.Clear();
	Object.QueryParameters.Clear();
	Object.Query = "";
	
	FillIndicatorsAndSourceDataFilterPeriods();
	GenerateQueryFillParameters();
	
EndProcedure

&AtClient
// Procedure - QueryBuilder click handler.
//
Procedure QueryAssistant(Command)
	
	#If ThickClientOrdinaryApplication OR ThickClientManagedApplication Then
		
		QueryAssistant = New QueryAssistant;
		QueryAssistant.AutoAppendPresentations = False;
		If Object.Query <> "" Then
			QueryAssistant.Text = Object.Query;
		EndIf;
		If QueryAssistant.DoModal() Then
			Object.Query = QueryAssistant.Text;
			QueryText =  QueryAssistant.Text;
		EndIf;
		
	#EndIf
	
EndProcedure // QueryBuilderExecute()

&AtClient
// Procedure - Execute event handler of the EditQuery field.
//
Procedure EditQuery(Command)
	
	If Object.CustomQuery Then
	
		If EditQuery Then
			If Not QueryCorrect() Then
				Response = Undefined;

				ShowQueryBox(New NotifyDescription("EditQueryEnd", ThisObject), NStr("en='Query contains error. Clear query and return to original one?';ru='Запрос содержит ошибку! Очистить запрос и вернуться к исходному?'"), QuestionDialogMode.YesNo, 0);
                Return;
			Else
				FillParametersByQuery();
			EndIf;
		Else
			QueryText = Object.Query;
		EndIf;
		
		EditQueryFragment();

		
	EndIf;
	
EndProcedure

&AtClient
Procedure EditQueryEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        Object.Query = QueryText;
    EndIf;
    
    EditQueryFragment();

EndProcedure

&AtClient
Procedure EditQueryFragment()
    
    EditQuery = Not EditQuery;
    Items.EditQuery.Check = EditQuery;
    Items.Pages.CurrentPage = Items.GroupQuery;
    Items.Query.Enabled = EditQuery;

EndProcedure // EditQueryExecute()

&AtClient
// Procedure - OnChange event handler of the Description field.
//
Procedure DescriptionOnChange(Item)
     
    GetID(Object.Description);

EndProcedure // DescriptionOnChange()

&AtClient
// Procedure - event handler OnChange of field SpecifyValueAtPayrollCalculation.
//
Procedure SpecifyValueAtPayrollCalculationOnChange(Item)
	
	If Object.SpecifyValueAtPayrollCalculation Then
	
		MessageText = NStr("en='After the check box is selected, all attributes will be cleared. Continue?';ru='После установки флага все реквизиты будут очищены! Продолжить?'");
		QuestionResult = Undefined;

		ShowQueryBox(New NotifyDescription("SpecifyValueAtPayrollCalculationOnChangeEnd", ThisObject), MessageText, QuestionDialogMode.YesNo);
        Return;
		
	EndIf;
	
	SpecifyValueAtPayrollCalculationOnChangeFragment();
EndProcedure

&AtClient
Procedure SpecifyValueAtPayrollCalculationOnChangeEnd(Result, AdditionalParameters) Export
    
    QuestionResult = Result;
    If QuestionResult <> DialogReturnCode.Yes Then
        Object.SpecifyValueAtPayrollCalculation = False;
        Return;
    EndIf;
    
    Object.SourceName = "";
    Object.SourcePresentation = "";
    Object.Query = "";
    Object.CustomQuery = False;
    Object.DataFilterPeriods.Clear();
    Object.Indicators.Clear();
    Object.QueryParameters.Clear();
    
    
    SpecifyValueAtPayrollCalculationOnChangeFragment();

EndProcedure

&AtClient
Procedure SpecifyValueAtPayrollCalculationOnChangeFragment()
    
    SetVisibleCurrentPageAtClient();

EndProcedure

&AtClient
// Procedure - OnChange event handler of the SpontaneousQuery field.
//
Procedure CustomQueryOnChange(Item)

	#If ThinClient OR WebClient Then
		Items.QueryAssistant.Enabled = False;
	#Else
		Items.QueryAssistant.Enabled = Object.CustomQuery;
	#EndIf
	
	SetEnabledAndVisibleAtServer();
	
	If Object.CustomQuery Then
		
		Object.SourceName = "";
		Object.SourcePresentation = "";
		Object.DataFilterPeriods.Clear();
		Object.Indicators.Clear();
		DataFilter.Settings.Filter.Items.Clear();
		
	Else
		
		Object.Query = "";
		Object.QueryParameters.Clear();
		
	EndIf; 
	
EndProcedure // SpontaneousQueryOnChange()

&AtClient
// Procedure - OnChange event handler of the SpontaneousQuery field.
//
Procedure IndicatorsUsageOnChange(Item)
	                                      
	If Items.Indicators.CurrentData.Use Then
		For Each TSRow IN Object.Indicators Do
            If TSRow <> Items.Indicators.CurrentData Then
				TSRow.Use = False;
			EndIf; 
		EndDo; 
	EndIf; 

EndProcedure // UsageOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABLE PARTS ATTRIBUTE EVENT HANDLERS

&AtClient
// Procedure - OnEditEnd event handler of the Filter table.
//
Procedure DataFilterSettingsFilterOnEditEnd(Item, NewRow, CancelEdit)
	
	If Not Object.CustomQuery Then
		GenerateQueryFillParameters();
	EndIf;

EndProcedure // FilterOnEditEnd()

&AtClient
// Procedure - OnEditEnd event handler of the Indicators table.
//
Procedure IndicatorsOnEditEnd(Item, NewRow, CancelEdit)
	
	If Not Object.CustomQuery Then
		GenerateQueryFillParameters();
	EndIf;

EndProcedure // IndicatorsOnEditEnd()

&AtClient
// Procedure - AfterDeletion event handler of the Filter table.
//
Procedure DataFilterSettingsFilterAfterDeleting(Item)
	
	If Not Object.CustomQuery Then
		GenerateQueryFillParameters();
	EndIf;
	
EndProcedure

&AtClient
// Procedure - Clear event handler of the Source field.
//
Procedure SourceClear(Item, StandardProcessing)
	
	Object.SourceName = "";
	Object.SourcePresentation = "";
	Object.DataFilterPeriods.Clear();
	Object.Indicators.Clear();	
	Object.Query = "";
	Object.QueryParameters.Clear();
	
EndProcedure

&AtClient
// Procedure - BeforeAddingBegin event handler of the Indicators table.
//
Procedure IndicatorsBeforeAdd(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

&AtClient
// Procedure - BeforeAddingBegin event handler of the DataFilterPeriods table.
//
Procedure DataFilterPeriodsBeforeAdd(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;	
	
EndProcedure

&AtClient
// Procedure - BeforeAddingBegin event handler of the QueryParameters table.
//
Procedure QueryParametersBeforeAdd(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FILLING BY TEMPLATES

&AtClient
Procedure CreateFixedAmount(Command)
	
	Notification = New NotifyDescription("FillByTemplateEnd",ThisForm,"FixedAmount");
	ShowQueryBox(Notification,NStr("en='Calculation parameter will be completely repopulated. Continue?';ru='Параметр расчета будет полностью перезаполнен! Продолжить?'"), QuestionDialogMode.YesNo, 0);
		
EndProcedure

&AtClient
Procedure CreateNormOfDays(Command)
	
	Notification = New NotifyDescription("FillByTemplateEnd",ThisForm,"NormDays");
	ShowQueryBox(Notification,NStr("en='Calculation parameter will be completely repopulated. Continue?';ru='Параметр расчета будет полностью перезаполнен! Продолжить?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure CreateNormOfHours(Command)
	
	Notification = New NotifyDescription("FillByTemplateEnd",ThisForm,"NormHours");
	ShowQueryBox(Notification,NStr("en='Calculation parameter will be completely repopulated. Continue?';ru='Параметр расчета будет полностью перезаполнен! Продолжить?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure CreateDaysWorked(Command)
	
	Notification = New NotifyDescription("FillByTemplateEnd",ThisForm,"DaysWorked");
	ShowQueryBox(Notification,NStr("en='Calculation parameter will be completely repopulated. Continue?';ru='Параметр расчета будет полностью перезаполнен! Продолжить?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure CreateHoursWorked(Command)
	
	Notification = New NotifyDescription("FillByTemplateEnd",ThisForm,"HoursWorked");
	ShowQueryBox(Notification,NStr("en='Calculation parameter will be completely repopulated. Continue?';ru='Параметр расчета будет полностью перезаполнен! Продолжить?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure CreateTariffRate(Command)
	
	Notification = New NotifyDescription("FillByTemplateEnd",ThisForm,"TariffRate");
	ShowQueryBox(Notification,NStr("en='Calculation parameter will be completely repopulated. Continue?';ru='Параметр расчета будет полностью перезаполнен! Продолжить?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure CreateHoursWorkedByJobs(Command)
	
	Notification = New NotifyDescription("FillByTemplateEnd",ThisForm,"HoursWorkedByJobs");
	ShowQueryBox(Notification,NStr("en='Calculation parameter will be completely repopulated. Continue?';ru='Параметр расчета будет полностью перезаполнен! Продолжить?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByTemplateEnd(Response,PatternName) Export
	
	If Response = DialogReturnCode.Yes Then
		FillByTemplate(PatternName);
	EndIf;
	
EndProcedure
