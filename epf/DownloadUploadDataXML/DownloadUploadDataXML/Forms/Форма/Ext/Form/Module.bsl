﻿
#Область ОбработчикиСобытийФормы

&НаСервере
Процедура ПриСозданииНаСервере(Отказ, СтандартнаяОбработка)
	
	Заголовок = NStr("ru='Выгрузка и загрузка данных XML (';en='Download Upload Data XML ('") + 
				РеквизитФормыВЗначение("Объект").ВерсияОбъекта() + ")";

	Если Параметры.Свойство("АвтоТест") Тогда
		Возврат;
	КонецЕсли;
	
	ПроверитьВерсиюИРежимСовместимостиПлатформы();
	
	РежимРаботыНаКлиенте = (РежимРаботыНаКлиентеИлиНаСервере = 0);
	
	Элементы.ИмяФайлаВыгрузки.Доступность = Не РежимРаботыНаКлиенте;
	Элементы.ИмяФайлаЗагрузки.Доступность = Не РежимРаботыНаКлиенте;
	
	ОбъектНаСервере = РеквизитФормыВЗначение("Объект");
	ОбъектНаСервере.Инициализация();
	ЗначениеВРеквизитФормы(ОбъектНаСервере.ДеревоМетаданных, "Объект.ДеревоМетаданных");
	
	Файл = Новый Файл(ИмяФайлаВыгрузки);
	Объект.ИспользоватьФорматFastInfoSet = (Файл.Расширение = ".fi");
	
	РежимВыгрузки = (Элементы.ГруппаРежим.ТекущаяСтраница = Элементы.ГруппаРежим.ПодчиненныеЭлементы.ГруппаВыгрузка);
	
КонецПроцедуры

&НаСервере
Процедура ПриЗагрузкеДанныхИзНастроекНаСервере(Настройки)
	
	РежимРаботыНаКлиенте = (РежимРаботыНаКлиентеИлиНаСервере = 0);
	
	Элементы.ИмяФайлаВыгрузки.Доступность = Не РежимРаботыНаКлиенте;
	Элементы.ИмяФайлаЗагрузки.Доступность = Не РежимРаботыНаКлиенте;
	
	Файл = Новый Файл(ИмяФайлаВыгрузки);
	Объект.ИспользоватьФорматFastInfoSet = (Файл.Расширение = ".fi");
	
	РежимВыгрузки = (Элементы.ГруппаРежим.ТекущаяСтраница = Элементы.ГруппаРежим.ПодчиненныеЭлементы.ГруппаВыгрузка);
	
КонецПроцедуры

&НаКлиенте
Процедура ОбработкаВыбора(ВыбранноеЗначение, ИсточникВыбора)
	
	ОбработкаВыбораНаСервере(ВыбранноеЗначение);
	
КонецПроцедуры

&НаКлиенте
Процедура ОбработкаОповещения(ИмяСобытия, Параметр, Источник)
	
	Если ИмяСобытия = "ЗакрытаФормаНастройкиКонсолиЗапросов" Тогда
		ЗаполнитьЗначенияСвойств(ЭтотОбъект, Параметр);
	КонецЕсли;
	
КонецПроцедуры

#КонецОбласти

#Область ОбработчикиСобытийЭлементовШапкиФормы

&НаКлиенте
Процедура ИмяФайлаВыгрузкиПриИзменении(Элемент)
	
	Файл = Новый Файл(ИмяФайлаВыгрузки);
	Объект.ИспользоватьФорматFastInfoSet = (Файл.Расширение = ".fi");
	
КонецПроцедуры

&НаКлиенте
Процедура ИмяФайлаВыгрузкиОткрытие(Элемент, СтандартнаяОбработка)
	
	ОткрытьВПриложении(Элемент, "ИмяФайлаВыгрузки", СтандартнаяОбработка);
	
КонецПроцедуры

&НаКлиенте
Процедура ИмяФайлаВыгрузкиНачалоВыбора(Элемент, ДанныеВыбора, СтандартнаяОбработка)
	
	ОбработатьНачалоВыбораФайла(СтандартнаяОбработка);
	
КонецПроцедуры

&НаКлиенте
Процедура ИспользоватьФорматFastInfoSetПриИзменении(Элемент)
	
	Если Объект.ИспользоватьФорматFastInfoSet Тогда
		ИмяФайлаВыгрузки = СтрЗаменить(ИмяФайлаВыгрузки, ".xml", ".fi");
	Иначе
		ИмяФайлаВыгрузки = СтрЗаменить(ИмяФайлаВыгрузки, ".fi", ".xml");
	КонецЕсли;
	
КонецПроцедуры

&НаКлиенте
Процедура ГруппаРежимПриСменеСтраницы(Элемент, ТекущаяСтраница)
	
	РежимВыгрузки = (Элементы.ГруппаРежим.ТекущаяСтраница = Элементы.ГруппаРежим.ПодчиненныеЭлементы.ГруппаВыгрузка);
	
КонецПроцедуры

&НаКлиенте
Процедура ДополнительныеОбъектыДляВыгрузкиПриИзменении(Элемент)
	
	Если Элемент.ТекущиеДанные <> Неопределено И ЗначениеЗаполнено(Элемент.ТекущиеДанные.Объект) Тогда
		
		Элемент.ТекущиеДанные.ИмяОбъектаДляЗапроса = ИмяОбъектаПоТипуДляЗапроса(Элемент.ТекущиеДанные.Объект);
		
	КонецЕсли;
	
КонецПроцедуры

&НаКлиенте
Процедура ИмяФайлаЗагрузкиОткрытие(Элемент, СтандартнаяОбработка)
	
	ОткрытьВПриложении(Элемент, "ИмяФайлаЗагрузки", СтандартнаяОбработка);
	
КонецПроцедуры

&НаКлиенте
Процедура ИмяФайлаЗагрузкиНачалоВыбора(Элемент, ДанныеВыбора, СтандартнаяОбработка)
	
	ОбработатьНачалоВыбораФайла(СтандартнаяОбработка);
	
КонецПроцедуры

#КонецОбласти

#Область ОбработчикиСобытийЭлементовТаблицыФормыДеревоМетаданных

&НаКлиенте
Процедура ДеревоМетаданныхВыгружатьПриИзменении(Элемент)
	
	ТекущиеДанные = Элементы.ДеревоМетаданных.ТекущиеДанные;
	
	Если ТекущиеДанные.Выгружать = 2 Тогда
		ТекущиеДанные.Выгружать = 0;
	КонецЕсли;
	
	УстановитьПометкиПодчиненных(ТекущиеДанные, "Выгружать");
	УстановитьПометкиРодителей(ТекущиеДанные, "Выгружать");
	
КонецПроцедуры

&НаКлиенте
Процедура ДеревоМетаданныхВыгружатьПриНеобходимостиПриИзменении(Элемент)
	
	ТекущиеДанные = Элементы.ДеревоМетаданных.ТекущиеДанные;
	
	Если ТекущиеДанные.ВыгружатьПриНеобходимости = 2 Тогда
		ТекущиеДанные.ВыгружатьПриНеобходимости = 0;
	КонецЕсли;
	
	УстановитьПометкиПодчиненных(ТекущиеДанные, "ВыгружатьПриНеобходимости");
	УстановитьПометкиРодителей(ТекущиеДанные, "ВыгружатьПриНеобходимости");
	
КонецПроцедуры

#КонецОбласти

#Область ОбработчикиСобытийЭлементовТаблицыФормыДополнительныеОбъектыДляВыгрузки

&НаКлиенте
Процедура ДополнительныеОбъектыДляВыгрузкиПередНачаломДобавления(Элемент, Отказ, Копирование, Родитель, Группа)
	
	Элемент.ТекущийЭлемент.ОграничениеТипа = ТипОбъектовДляВыгрузки;
	
КонецПроцедуры

#КонецОбласти

#Область ОбработчикиКомандФормы

&НаКлиенте
Процедура ДобавитьИзЗапроса(Команда)
	
	ОткрытьФорму(ИмяФормыКонсолиЗапросов(),ПараметрыКонсолиЗапросов(),ЭтотОбъект);
	
КонецПроцедуры

&НаКлиенте
Процедура ОчиститьДополнительныеОбъектыВыгрузки(Команда)
	
	Объект.ДополнительныеОбъектыДляВыгрузки.Очистить();
	
КонецПроцедуры

&НаКлиенте
Процедура ВыгрузитьДанные(Команда)
	
	Объект.ДатаНачала = ПериодВыгрузки.ДатаНачала;
	Объект.ДатаОкончания = ПериодВыгрузки.ДатаОкончания;
	
	ОчиститьСообщения();
	
	Если Не РежимРаботыНаКлиенте Тогда
		
		Если ПустаяСтрока(ИмяФайлаВыгрузки) Тогда
			
			ТекстСообщения = Нстр("ru='Поле ""Имя файла"" не заполнено';
								  |en='Field ""File name"" is not filled'");
			СообщитьПользователю(ТекстСообщения, "ИмяФайлаВыгрузки");
			Возврат;
			
		КонецЕсли;
		
	КонецЕсли;
	
	Состояние(Нстр("ru='Выполняется выгрузка данных. Пожалуйста, подождите...';
				   |en='Выполняется выгрузка данных. Пожалуйста, подождите...'"));
	
	АдресФайлаВоВременномХранилище = "";
	ВыгрузитьДанныеНаСервере(АдресФайлаВоВременномХранилище);
	
	Если РежимРаботыНаКлиенте И Не ПустаяСтрока(АдресФайлаВоВременномХранилище) Тогда
		
		ИмяФайла = Нстр("ru='Файл выгрузки';en='Data File'") + 
				   ?(Объект.ИспользоватьФорматFastInfoSet, ".fi", ".xml");
		ПолучитьФайл(АдресФайлаВоВременномХранилище, ИмяФайла);
		
	КонецЕсли;
	
КонецПроцедуры

&НаКлиенте
Процедура ЗагрузитьДанные(Команда)
	
	ОчиститьСообщения();
	АдресФайлаВоВременномХранилище = "";
	
	Если РежимРаботыНаКлиенте Тогда
		
		ОписаниеОповещения = Новый ОписаниеОповещения("ЗагрузитьДанныеЗавершение", ЭтотОбъект);
		НачатьПомещениеФайла(ОписаниеОповещения, АдресФайлаВоВременномХранилище,Нстр("ru = 'Файл выгрузки'"),, УникальныйИдентификатор);
		
	Иначе
		
		Если ПустаяСтрока(ИмяФайлаЗагрузки) Тогда
			
			ТекстСообщения = Нстр("ru='Поле ""Имя файла"" не заполнено';en='Поле ""Имя файла"" не заполнено'");
			СообщитьПользователю(ТекстСообщения, "ИмяФайлаЗагрузки");
			Возврат;
			
		КонецЕсли;
		
		Файл = Новый Файл(ИмяФайлаЗагрузки);
		Если Не Файл.Существует() Тогда
			
			ТекстСообщения = Нстр("ru='Файл не существует';en='File does not exist'");
			СообщитьПользователю(ТекстСообщения, "ИмяФайлаЗагрузки");
			Возврат;
			
		КонецЕсли;
		
		ЗагрузитьДанныеЗавершение(Истина, АдресФайлаВоВременномХранилище, ИмяФайлаЗагрузки, Неопределено);
		
	КонецЕсли;
	
КонецПроцедуры

&НаКлиенте
Процедура НастройкиКонсолиЗапросов(Команда)
	
	ПараметрыФормы = Новый Структура;
	ПараметрыФормы.Вставить("ВариантИспользованияКонсолиЗапросов", ВариантИспользованияКонсолиЗапросов);
	ПараметрыФормы.Вставить("ПутьКВнешнейКонсолиЗапросов", ПутьКВнешнейКонсолиЗапросов);
	
	ОткрытьФорму(ИмяФормыНастроекКонсолиЗапросов(), ПараметрыФормы);
	
КонецПроцедуры

&НаКлиенте
Процедура ПересчитатьВыгружаемыеПоСсылке(Команда)
	
	Состояние(Нстр("ru='Выполняется поиск объектов метаданных, которые могут быть выгружены по ссылкам...';
				   |en='Выполняется поиск объектов метаданных, которые могут быть выгружены по ссылкам...'"));
	СохранитьОтображениеДерева(Объект.ДеревоМетаданных.ПолучитьЭлементы());
	ПересчитатьВыгружаемыеПоСсылкеНаСервере();
	ВосстановитьОтображениеДерева(Объект.ДеревоМетаданных.ПолучитьЭлементы());
	
КонецПроцедуры

#КонецОбласти

#Область СлужебныеПроцедурыИФункции

&НаСервере
Функция ИмяФормыКонсолиЗапросов()
	
	Если ВариантИспользованияКонсолиЗапросов = 0 Тогда
		
		Обработка = РеквизитФормыВЗначение("Объект");
		ИдентификаторФормы = ".Форма.ВыборИзЗапроса";
		
	ИначеЕсли ВариантИспользованияКонсолиЗапросов = 1 Тогда
		
		Обработка = Обработки["КонсольЗапросов"].Создать();
		ИдентификаторФормы = ".Форма";
		
	Иначе //ВариантИспользованияКонсолиЗапросов = 2
		
		Обработка = ВнешниеОбработки.Создать(ПутьКВнешнейКонсолиЗапросов);
		ИдентификаторФормы = ".ФормаОбъекта";
		
	КонецЕсли;
	
	Возврат Обработка.Метаданные().ПолноеИмя() + ИдентификаторФормы;
	
КонецФункции

&НаСервере
Функция ИмяФормыНастроекКонсолиЗапросов()
	
	Обработка = РеквизитФормыВЗначение("Объект");
	ИмяФормыНастроек = Обработка.Метаданные().ПолноеИмя() + ".Форма.НастройкиКонсолиЗапросов";
	
	Возврат ИмяФормыНастроек;
	
КонецФункции

&НаКлиенте
Функция ПараметрыКонсолиЗапросов()
	
	ПараметрыФормы = Новый Структура;
	
	Если ВариантИспользованияКонсолиЗапросов = 0 Тогда
		
		ПараметрыФормы.Вставить("ВариантИспользованияКонсолиЗапросов", ВариантИспользованияКонсолиЗапросов);
		ПараметрыФормы.Вставить("ПутьКВнешнейКонсолиЗапросов", ПутьКВнешнейКонсолиЗапросов);
		
	Иначе
		
		ПараметрыФормы.Вставить("Заголовок", НСтр("ru='Выбор данных для выгрузки';en='Выбор данных для выгрузки'"));
		ПараметрыФормы.Вставить("РежимВыбора", Истина);
		ПараметрыФормы.Вставить("ЗакрыватьПриВыборе", Ложь);
		
	КонецЕсли;
	
	Возврат ПараметрыФормы;
	
КонецФункции

&НаКлиенте
Процедура ОткрытьВПриложении(Элемент, ПутьКДанным, СтандартнаяОбработка)

	Файл = Новый Файл(Элемент.ТекстРедактирования);
	
	Если Файл.Существует() Тогда
		
		ЗапуститьПриложение(Элемент.ТекстРедактирования);
		
	Иначе
		
		СообщитьПользователю(Нстр("ru='Файл не найден';en='File not found'"), ПутьКДанным);
		
	КонецЕсли;
	
	СтандартнаяОбработка = Ложь;
	
КонецПроцедуры

&НаКлиенте
Процедура ПриИзмененииРежимаРаботы()
	
	РежимРаботыНаКлиенте = (РежимРаботыНаКлиентеИлиНаСервере = 0);
	
	Элементы.ИмяФайлаВыгрузки.Доступность = Не РежимРаботыНаКлиенте;
	Элементы.ИмяФайлаЗагрузки.Доступность = Не РежимРаботыНаКлиенте;
	
КонецПроцедуры

&НаКлиентеНаСервереБезКонтекста
Процедура СообщитьПользователю(Текст, ПутьКДанным = "")
	
	Сообщение = Новый СообщениеПользователю;
	Сообщение.Текст = Текст;
	Сообщение.ПутьКДанным = ПутьКДанным;
	Сообщение.Сообщить();
	
КонецПроцедуры

&НаКлиенте
Процедура ОбработатьНачалоВыбораФайла(СтандартнаяОбработка)
	
	СтандартнаяОбработка = Ложь;
	РежимДиалога = ?(РежимВыгрузки, РежимДиалогаВыбораФайла.Сохранение, РежимДиалогаВыбораФайла.Открытие);
	ДиалогВыбораФайла = Новый ДиалогВыбораФайла(РежимДиалога);
	ДиалогВыбораФайла.ПроверятьСуществованиеФайла = Не РежимВыгрузки;
	ДиалогВыбораФайла.МножественныйВыбор = Ложь;
	ДиалогВыбораФайла.Заголовок = Нстр("ru='Задайте имя файла выгрузки';en='Задайте имя файла выгрузки'");
	ДиалогВыбораФайла.ПолноеИмяФайла = ?(РежимВыгрузки, ИмяФайлаВыгрузки, ИмяФайлаЗагрузки);
	
	ДиалогВыбораФайла.Фильтр = "Формат выгрузки(*.xml)|*.xml|FastInfoSet (*.fi)|*.fi|Все файлы (*.*)|*.*";
	Если ДиалогВыбораФайла.Выбрать() Тогда
		Если РежимВыгрузки Тогда
			ИмяФайлаВыгрузки = ДиалогВыбораФайла.ПолноеИмяФайла;
		Иначе
			ИмяФайлаЗагрузки = ДиалогВыбораФайла.ПолноеИмяФайла;
		КонецЕсли;
	КонецЕсли;
	
КонецПроцедуры

&НаКлиенте
Процедура УстановитьПометкиПодчиненных(ТекСтрока, ИмяФлажка)
	
	Подчиненные = ТекСтрока.ПолучитьЭлементы();
	
	Если Подчиненные.Количество() = 0 Тогда
		Возврат;
	КонецЕсли;
	
	Для Каждого Строка из Подчиненные Цикл
		
		Строка[ИмяФлажка] = ТекСтрока[ИмяФлажка];
		
		УстановитьПометкиПодчиненных(Строка, ИмяФлажка);
		
	КонецЦикла;
		
КонецПроцедуры

&НаКлиенте
Процедура УстановитьПометкиРодителей(ТекСтрока, ИмяФлажка)
	
	Родитель = ТекСтрока.ПолучитьРодителя();
	Если Родитель = Неопределено Тогда
		Возврат;
	КонецЕсли; 
	
	ТекСостояние = Родитель[ИмяФлажка];
	
	НайденыВключенные  = Ложь;
	НайденыВыключенные = Ложь;
	
	Для Каждого Строка из Родитель.ПолучитьЭлементы() Цикл
		Если Строка[ИмяФлажка] = 0 Тогда
			НайденыВыключенные = Истина;
		ИначеЕсли Строка[ИмяФлажка] = 1
			ИЛИ Строка[ИмяФлажка] = 2 Тогда
			НайденыВключенные  = Истина;
		КонецЕсли; 
		Если НайденыВключенные И НайденыВыключенные Тогда
			Прервать;
		КонецЕсли; 
	КонецЦикла;
	
	Если НайденыВключенные И НайденыВыключенные Тогда
		Включить = 2;
	ИначеЕсли НайденыВключенные И (Не НайденыВыключенные) Тогда
		Включить = 1;
	ИначеЕсли (Не НайденыВключенные) И НайденыВыключенные Тогда
		Включить = 0;
	ИначеЕсли (Не НайденыВключенные) И (Не НайденыВыключенные) Тогда
		Включить = 2;
	КонецЕсли;
	
	Если Включить = ТекСостояние Тогда
		Возврат;
	Иначе
		Родитель[ИмяФлажка] = Включить;
		УстановитьПометкиРодителей(Родитель, ИмяФлажка);
	КонецЕсли; 
	
КонецПроцедуры

&НаСервере
Процедура ВыгрузитьДанныеНаСервере(АдресФайлаВоВременномХранилище)
	
	Если РежимРаботыНаКлиенте Тогда
		
		Расширение = ?(Объект.ИспользоватьФорматFastInfoSet, ".fi", ".xml");
		ИмяВременногоФайла = ПолучитьИмяВременногоФайла(Расширение);
		
	Иначе
		
		ИмяВременногоФайла = ИмяФайлаВыгрузки;
		
	КонецЕсли;
	
	ОбъектНаСервере = РеквизитФормыВЗначение("Объект");
	ЗаполнитьДеревоМетаданныхНаСервере(ОбъектНаСервере);
	
	ОбъектНаСервере.ВыполнитьВыгрузку(ИмяВременногоФайла);
	
	Если РежимРаботыНаКлиенте Тогда
		
		Файл = Новый Файл(ИмяВременногоФайла);
		
		Если Файл.Существует() Тогда
			
			ДвоичныеДанные = Новый ДвоичныеДанные(ИмяВременногоФайла);
			АдресФайлаВоВременномХранилище = ПоместитьВоВременноеХранилище(ДвоичныеДанные, УникальныйИдентификатор);
			УдалитьФайлы(ИмяВременногоФайла);
			
		КонецЕсли;
		
	КонецЕсли;
	
КонецПроцедуры

&НаСервере
Процедура ПроставитьПометкиВыгружаемыхДанных(СтрокиИсходногоДерева, СтрокиЗаменяемогоДерева)
	
	КолонкаВыгружать = СтрокиЗаменяемогоДерева.ВыгрузитьКолонку("Выгружать");
	СтрокиИсходногоДерева.ЗагрузитьКолонку(КолонкаВыгружать, "Выгружать");
	
	КолонкаВыгружатьПриНеобходимости = СтрокиЗаменяемогоДерева.ВыгрузитьКолонку("ВыгружатьПриНеобходимости");
	СтрокиИсходногоДерева.ЗагрузитьКолонку(КолонкаВыгружатьПриНеобходимости, "ВыгружатьПриНеобходимости");
	
	КолонкаРазвернут = СтрокиЗаменяемогоДерева.ВыгрузитьКолонку("Развернут");
	СтрокиИсходногоДерева.ЗагрузитьКолонку(КолонкаРазвернут, "Развернут");
	
	Для Каждого СтрокаИсходногоДерева Из СтрокиИсходногоДерева Цикл
		
		ИндексСтроки = СтрокиИсходногоДерева.Индекс(СтрокаИсходногоДерева);
		СтрокаИзменяемогоДерева = СтрокиЗаменяемогоДерева.Получить(ИндексСтроки);
		
		ПроставитьПометкиВыгружаемыхДанных(СтрокаИсходногоДерева.Строки, СтрокаИзменяемогоДерева.Строки);
		
	КонецЦикла;
	
КонецПроцедуры

&НаКлиенте
Процедура ЗагрузитьДанныеЗавершение(Результат, Адрес, ВыбранноеИмяФайла, ДополнительныеПараметры) Экспорт
	
	Если Результат Тогда
		
		Состояние(Нстр("ru='Выполняется загрузка данных. Пожалуйста, подождите...';
					   |en='Выполняется загрузка данных. Пожалуйста, подождите...'"));
		
		Файл = Новый Файл(ВыбранноеИмяФайла);
		Если Не Файл.Существует() Тогда
			
			ТекстСообщения = Нстр("ru='Указанный файл не существует';en='Указанный файл не существует'");
			ПутьКДанным = ?(РежимРаботыНаКлиенте, "", "ИмяФайлаЗагрузки");
			СообщитьПользователю(ТекстСообщения, ПутьКДанным);
			Возврат;
			
		КонецЕсли;
		
		ЗагрузитьДанныеНаСервере(Адрес, Файл.Расширение);
	
	КонецЕсли;
	
КонецПроцедуры

&НаСервере
Процедура ЗагрузитьДанныеНаСервере(АдресФайлаВоВременномХранилище, Расширение)
	
	Если РежимРаботыНаКлиенте Тогда
		
		ДвоичныеДанные = ПолучитьИзВременногоХранилища(АдресФайлаВоВременномХранилище);
		ИмяВременногоФайла = ПолучитьИмяВременногоФайла(Расширение);
		ДвоичныеДанные.Записать(ИмяВременногоФайла);
		
	Иначе
		
		ИмяВременногоФайла = ИмяФайлаЗагрузки;
		
	КонецЕсли;
	
	РеквизитФормыВЗначение("Объект").ВыполнитьЗагрузку(ИмяВременногоФайла);
	
	Если РежимРаботыНаКлиенте Тогда
		
		Файл = Новый Файл(ИмяВременногоФайла);
		
		Если Файл.Существует() Тогда
			
			УдалитьФайлы(ИмяВременногоФайла);
			
		КонецЕсли;
		
	КонецЕсли;
	
КонецПроцедуры

&НаСервере
Процедура ПересчитатьВыгружаемыеПоСсылкеНаСервере()
	
	ОбъектНаСервере = РеквизитФормыВЗначение("Объект");
	ЗаполнитьДеревоМетаданныхНаСервере(ОбъектНаСервере);
	ОбъектНаСервере.СоставВыгрузки(Истина);
	ЗначениеВРеквизитФормы(ОбъектНаСервере.ДеревоМетаданных, "Объект.ДеревоМетаданных");
	
КонецПроцедуры

&НаСервере
Процедура ЗаполнитьДеревоМетаданныхНаСервере(ОбъектНаСервере)
	
	ДеревоМетаданных = РеквизитФормыВЗначение("Объект.ДеревоМетаданных");
	
	ОбъектНаСервере.Инициализация();
	
	ПроставитьПометкиВыгружаемыхДанных(ОбъектНаСервере.ДеревоМетаданных.Строки, ДеревоМетаданных.Строки);
	
КонецПроцедуры

&НаКлиенте
Процедура СохранитьОтображениеДерева(СтрокиДерева)
	
	Для Каждого Строка Из СтрокиДерева Цикл
		
		ИдентификаторСтроки=Строка.ПолучитьИдентификатор();
		Строка.Развернут = Элементы.ДеревоМетаданных.Развернут(ИдентификаторСтроки);
		
		СохранитьОтображениеДерева(Строка.ПолучитьЭлементы());
		
	КонецЦикла;
	
КонецПроцедуры

&НаКлиенте
Процедура ВосстановитьОтображениеДерева(СтрокиДерева)
	
	Для Каждого Строка Из СтрокиДерева Цикл
		
		ИдентификаторСтроки=Строка.ПолучитьИдентификатор();
		Если Строка.Развернут Тогда
			Элементы.ДеревоМетаданных.Развернуть(ИдентификаторСтроки);
		КонецЕсли;
		
		ВосстановитьОтображениеДерева(Строка.ПолучитьЭлементы());
		
	КонецЦикла;
	
КонецПроцедуры

&НаСервереБезКонтекста
Функция ИмяОбъектаПоТипуДляЗапроса(Ссылка)
	
	МетаданныеОбъекта = Ссылка.Метаданные();
	ИмяМетаданных = МетаданныеОбъекта.Имя;
	
	ИмяДляЗапроса = "";
	
	Если Метаданные.Справочники.Содержит(МетаданныеОбъекта) Тогда
		ИмяДляЗапроса = "Справочник";
	ИначеЕсли Метаданные.Документы.Содержит(МетаданныеОбъекта) Тогда
		ИмяДляЗапроса = "Документ";
	ИначеЕсли Метаданные.ПланыВидовХарактеристик.Содержит(МетаданныеОбъекта) Тогда
		ИмяДляЗапроса = "ПланВидовХарактеристик";
	ИначеЕсли Метаданные.ПланыСчетов.Содержит(МетаданныеОбъекта) Тогда
		ИмяДляЗапроса = "ПланСчетов";
	ИначеЕсли Метаданные.ПланыВидовРасчета.Содержит(МетаданныеОбъекта) Тогда
		ИмяДляЗапроса = "ПланВидовРасчета";
	ИначеЕсли Метаданные.ПланыОбмена.Содержит(МетаданныеОбъекта) Тогда
		ИмяДляЗапроса = "ПланОбмена";
	ИначеЕсли Метаданные.БизнесПроцессы.Содержит(МетаданныеОбъекта) Тогда
		ИмяДляЗапроса = "БизнесПроцесс";
	ИначеЕсли Метаданные.Задачи.Содержит(МетаданныеОбъекта) Тогда
		ИмяДляЗапроса = "Задача";
	КонецЕсли;
	
	Если ПустаяСтрока(ИмяДляЗапроса) Тогда
		Возврат "";
	Иначе
		Возврат ИмяДляЗапроса + "." + ИмяМетаданных;
	КонецЕсли;
	
КонецФункции

&НаСервере
Процедура ОбработкаВыбораНаСервере(ВыбранныеЗначения)
	
	Если ТипЗнч(ВыбранныеЗначения) = Тип("Структура") Тогда
		
		РезультатЗапроса = ПолучитьИзВременногоХранилища(ВыбранныеЗначения.ДанныеВыбора);
		
		Если ТипЗнч(РезультатЗапроса)=Тип("Массив") Тогда
			
			РезультатЗапроса = РезультатЗапроса[РезультатЗапроса.ВГраница()];
			
			Если РезультатЗапроса.Колонки.Найти("Ссылка") <> Неопределено Тогда
				ВыбранныеСсылки = РезультатЗапроса.Выгрузить();
			КонецЕсли;
			
		КонецЕсли;
		
	Иначе
		
		ВыбранныеСсылки = ВыбранныеЗначения;
		
	КонецЕсли;
	
	Для Каждого Значение Из ВыбранныеСсылки Цикл
		
		НоваяСтрока = Объект.ДополнительныеОбъектыДляВыгрузки.Добавить();
		НоваяСтрока.Объект = Значение.Ссылка;
		НоваяСтрока.ИмяОбъектаДляЗапроса = ИмяОбъектаПоТипуДляЗапроса(Значение.Ссылка);
		
	КонецЦикла
	
КонецПроцедуры

&НаКлиенте
Процедура ВыгрузкаНаКлиентеИлиНаСервереПриИзменении(Элемент)
	
	ПриИзмененииРежимаРаботы();
	
КонецПроцедуры

&НаКлиенте
Процедура ЗагрузкаНаКлиентеИлиНаСервереПриИзменении(Элемент)
	
	ПриИзмененииРежимаРаботы();
	
КонецПроцедуры

&НаСервере
Функция ПроверитьВерсиюИРежимСовместимостиПлатформы()
	
	Информация = Новый СистемнаяИнформация;
	Если Не (Лев(Информация.ВерсияПриложения, 3) = "8.3"
		И (Метаданные.РежимСовместимости = Метаданные.СвойстваОбъектов.РежимСовместимости.НеИспользовать
		Или (Метаданные.РежимСовместимости <> Метаданные.СвойстваОбъектов.РежимСовместимости.Версия8_1
		И Метаданные.РежимСовместимости <> Метаданные.СвойстваОбъектов.РежимСовместимости.Версия8_2_13
		И Метаданные.РежимСовместимости <> Метаданные.СвойстваОбъектов.РежимСовместимости["Версия8_2_16"]
		И Метаданные.РежимСовместимости <> Метаданные.СвойстваОбъектов.РежимСовместимости["Версия8_3_1"]
		И Метаданные.РежимСовместимости <> Метаданные.СвойстваОбъектов.РежимСовместимости["Версия8_3_2"]))) Тогда
		
		ВызватьИсключение Нстр("ru='Обработка предназначена для запуска на версии платформы
									|1С:Предприятие 8.3 с отключенным режимом совместимости 
									|или более поздних';
							   |en='Обработка предназначена для запуска на версии платформы
									|1С:Предприятие 8.3 с отключенным режимом совместимости 
									|или более поздних'");
		
	КонецЕсли;
	
КонецФункции

&AtClient
Procedure SaveSettings(Command)
	
	#If Not WebClient Then
	ArrayOfChecked = New Array;
	For Each UpperRow In Объект.ДеревоМетаданных.GetItems() Do
		// This is upper level with name of configuration.
		For Each MetadataRow In UpperRow.GetItems() Do
			// This is level with name of metadata, for example Catalogs, constats and other.
			Prefix = MetadataRow.ПолноеИмяМетаданных;
			For Each ObjectRow In MetadataRow.GetItems() Do
				// This is lower level with object.
				If ObjectRow.Выгружать Then
					ArrayOfChecked.Add(StrTemplate("%1.%2", Prefix, ObjectRow.ПолноеИмяМетаданных));
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	If ArrayOfChecked.Count() = 0 Then
		Return;
	EndIf;
	
	TextDocument = New TextDocument;
	For Each CheckedObject In ArrayOfChecked Do
		TextDocument.AddLine(CheckedObject);
	EndDo;
	
	FileDialog = New FileDialog(FileDialogMode.Save);
	FileDialog.Filter = "*.txt";
	FileDialog.DefaultExt = "txt";
	FileDialog.FullFileName = NStr("ru='НастройкиВыгрузкиЗагрузки.txt';en='SettingsOfLoadUnload.txt'");
	If FileDialog.Choose() Then
		TextDocument.Write(FileDialog.FullFileName);
	EndIf;
	#EndIf

EndProcedure

&AtClient
Procedure LoadSettings(Command)
	
	FileDialog = New FileDialog(FileDialogMode.Open);
	FileDialog.Filter = "*.txt";
	FileDialog.DefaultExt = "txt";
	FileDialog.FullFileName = NStr("ru='НастройкиВыгрузкиЗагрузки.txt';en='SettingsOfLoadUnload.txt'");
	If Not FileDialog.Choose() Then
		Return;
	EndIf;
	
	TextDocument = New TextDocument;
	TextDocument.Read(FileDialog.FullFileName);
	Structure = New Structure;
	For Count = 1 To TextDocument.LineCount() Do
		RowText = TextDocument.GetLine(Count);
		PointPosition = StrFind(RowText, ".");
		Metadata = Left(RowText, PointPosition-1);
		ObjectData = StrReplace(RowText, Metadata + ".", "");
		If Not Structure.Property(Metadata) Then
			Structure.Insert(Metadata, New Array);
		EndIf;
		Structure[Metadata].Add(ObjectData); 
	EndDo;
	
	For Each UpperRow In Объект.ДеревоМетаданных.GetItems() Do
		// This is upper level with name of configuration.
		For Each MetadataRow In UpperRow.GetItems() Do
			// This is level with name of metadata, for example Catalogs, constats and other.
			Prefix = MetadataRow.ПолноеИмяМетаданных;
			If Not Structure.Property(Prefix) Then
				Continue;
			EndIf;
			
			For Each ObjectRow In MetadataRow.GetItems() Do
				If Structure[Prefix].Find(ObjectRow.ПолноеИмяМетаданных) <> Undefined Then
					ObjectRow.Выгружать = Истина;
					УстановитьПометкиРодителей(ObjectRow, "Выгружать");
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
EndProcedure

#КонецОбласти
