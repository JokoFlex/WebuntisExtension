//
//  WebuntisModels.swift
//  WebuntisExtension
//
//  Created by Christopher Haindl on 15.04.23.
//

import Foundation
import SwiftUI

struct Subject: Decodable, Equatable
{
    let id: Int
    let name: String
    let longName: String
    let alternateName: String
    let active: Bool

    static let empty: Subject = Subject(id: 0, name: "Other", longName: "Sonstiges Event", alternateName: "", active: false)
}
struct Department: Decodable
{
    let id: Int
    let name: String
    let longName: String
}
struct Room: Decodable
{
    let id: Int
    let name: String
    let longName: String
    let active: Bool
    let foreColor: Color
    let backColor: Color
    let did: Int
    let building: String

    enum CodingKeys: String, CodingKey {
        case id, name, longName, active, foreColor, backColor, did, building
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        longName = try container.decode(String.self, forKey: .longName)
        active = try container.decode(Bool.self, forKey: .active)
        foreColor = try Color(hex: "0x" + (container.decodeIfPresent(String.self, forKey: .foreColor) ?? "000000"))
        backColor = try Color(hex: "0x" + (container.decodeIfPresent(String.self, forKey: .backColor) ?? "000000"))
        did = try container.decode(Int.self, forKey: .did)
        building = try container.decode(String.self, forKey: .building)
    }
}
struct Klasse: Decodable, Equatable
{
    let id: Int
    let name: String
    let longName: String
    let active: Bool
    let teacher1: Int
    let teacher2: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, longName, active, teacher1, teacher2
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        longName = try container.decode(String.self, forKey: .longName)
        active = try container.decode(Bool.self, forKey: .active)
        teacher1 = try container.decodeIfPresent(Int.self, forKey: .teacher1) ?? 0
        teacher2 = try container.decodeIfPresent(Int.self, forKey: .teacher2)
    }

}

struct Holiday: Decodable
{
    let id: Int
    let name: String
    let longName: String
    let startDate: Date
    let endDate: Date

    enum CodingKeys: String, CodingKey {
        case id, name, longName, startDate, endDate
    }

    init(from decoder: Decoder) throws {

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        longName = try container.decode(String.self, forKey: .longName)
        startDate = try dateFormatter.date(from: String(container.decode(Int.self, forKey: .startDate))) ?? Date()
        endDate = try dateFormatter.date(from: String(container.decode(Int.self, forKey: .endDate))) ?? Date()
    }
}

struct TimeGrid: Decodable
{
    let day: Int
    var timeUnits: [LessonSpan]

    private init()
    {
        day = -1
        timeUnits = []
    }

    static let empty = TimeGrid()

    enum CodingKeys: String, CodingKey {
        case day, timeUnits
    }

    init(from decoder: Decoder) throws {

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.day = try container.decode(Int.self, forKey: .day)
        self.timeUnits = try container.decode([LessonSpan].self, forKey: .timeUnits).sorted(by: { $0.startTime < $1.startTime })
    }
}

struct Weekplan
{
    private(set) var mondayOfWeek: Date = Date()
    private(set) var days: [Dayplan] = []

    init(webuntis: WebUntisAPI, lessons: [Lesson], mondayOfWeek: Date)
    {
        self.mondayOfWeek = mondayOfWeek
        var days: [Dayplan] = []
        for i in 1...5
        {
            days.append(Dayplan(webuntis: webuntis, sourceLessons: lessons.filter({ $0.dayOfWeek == i })))
        }
        self.days = days
    }

    private init()
    {

    }

    static let empty = Weekplan()

    struct Dayplan
    {
        private(set) var hours: [[Lesson]] = []

        init(webuntis: WebUntisAPI, sourceLessons: [Lesson])
        {
            let sortedLessons = sourceLessons.sorted(by: { $0.startTime < $1.startTime })
            var i = 0
            while i < sortedLessons.count
            {
                // Freistunden adden
                while webuntis.timeGrid.timeUnits[min(hours.count, webuntis.timeGrid.timeUnits.count - 1)].startTime < sortedLessons[i].startTime
                {
                    hours.append([])
                    if hours.count >= webuntis.timeGrid.timeUnits.count - 1
                    {
                        break
                    }
                }
                let newHours = sortedLessons.filter() { $0.startTime == webuntis.timeGrid.timeUnits[hours.count].startTime }
                hours.append(newHours)
                i += newHours.count
            }

            i = 0
            while i < hours.count - 1
            {
                if hours[i].count == 1 &&
                    hours[i + 1].count == 1 &&
                    hours[i][0].subject == hours[i + 1][0].subject
                {
                    hours[i][0].changeDurations(newEndTime: hours[i + 1][0].endTime, newDuration: hours[i][0].durationInHours + 1)
                    hours.remove(at: i + 1)
                }
                else
                {
                    i += 1
                }
            }
        }
    }
}

struct Lesson: Equatable
{
    static func == (lhs: Lesson, rhs: Lesson) -> Bool {
        return lhs.teachers == rhs.teachers && lhs.subject == rhs.subject && lhs.klassen == rhs.klassen && lhs.dayOfWeek == rhs.dayOfWeek && lhs.startTime == rhs.startTime
    }

    let id: Int
    let dayOfWeek: Int // Monday = 1
    private(set) var startTime: Int
    private(set) var endTime: Int
    private(set) var durationInHours: Int
    private(set) var hourIndex: Int
    let code: LessonSpecification
    let klassen: [Klasse]
    let teachers: [Teacher]
    let subject: Subject
    let rooms: [Room]

    mutating func changeDurations(newHourIndex: Int? = nil, newStartTime: Int? = nil, newEndTime: Int? = nil, newDuration: Int? = nil)
    {
        self.hourIndex = newHourIndex ?? self.hourIndex
        self.startTime = newStartTime ?? self.startTime
        self.endTime = newEndTime ?? self.endTime
        self.durationInHours = newDuration ?? self.durationInHours
    }

    func getColor() -> Color
    {
        if self.code == .cancelled
        {
            return self.code.getColorOfSpecify().background
        }

        switch(self.subject.name)
        {
        case "AM":
            return Color(hex: "0xfa8b2a")
        case "E1":
            return Color(hex: "0x4a80ed")
        case "RK":
            return Color(hex: "0xa88e39")
        case "D":
            return Color(hex: "0x3ee625")
        case "SPA":
            return Color(hex: "0x87e340")
        case "LWS3":
            return Color(hex: "0xe06cd3")
        default:
            return Color(hex: "0xe1e9f1")
        }
    }

    func timeAsString() -> (start: String, end: String)
    {
        return ((String(startTime / 100) + ":" + String(format: "%02d", startTime % 100)), (String(endTime / 100) + ":" + String(format: "%02d", endTime % 100)))
    }

    func isExcursion() -> Bool
    {
        return durationInHours > 4
    }

    init(webuntisAPI: WebUntisAPI, decodedLesson: DecodedLesson)
    {
        let calendar = Calendar.current
        self.id = decodedLesson.id
        self.dayOfWeek = calendar.component(.weekday, from: decodedLesson.date) - 1
        self.code = LessonSpecification(rawValue: decodedLesson.code ?? "") ?? LessonSpecification.ls
        self.startTime = max(decodedLesson.startTime, webuntisAPI.timeGrid.timeUnits[0].startTime)
        self.endTime = min(decodedLesson.endTime, webuntisAPI.timeGrid.timeUnits[webuntisAPI.timeGrid.timeUnits.count - 2].endTime)
        var startingHour: Int = 0
        var endingHour: Int = 0
        var hourIndex = 0
        for i in 0..<webuntisAPI.timeGrid.timeUnits.count
        {
            if webuntisAPI.timeGrid.timeUnits[i].startTime == self.startTime
            {
                startingHour = i
                hourIndex = i + 1
            }
            if webuntisAPI.timeGrid.timeUnits[i].endTime == self.endTime
            {
                endingHour = i
            }
        }
        self.hourIndex = hourIndex
        if endingHour < startingHour
        {
            endingHour = startingHour
        }
        self.durationInHours = endingHour - startingHour + 1

        self.klassen = webuntisAPI.klassen.filter({ decodedLesson.klassen.contains($0.id) })
        self.teachers = decodedLesson.teachers
        if decodedLesson.subject == 0
        {
            self.subject = Subject.empty
        }
        else
        {
            self.subject = webuntisAPI.subjects.filter({ decodedLesson.subject == $0.id })[0]
        }
        self.rooms = webuntisAPI.rooms.filter({ decodedLesson.rooms.contains($0.id) })
    }

    static func convertTable(webuntisAPI: WebUntisAPI, jsonData: String) throws -> [Lesson]
    {
        let decodedLessons = try JSONDecoder().decode([DecodedLesson].self, from: Data(jsonData.utf8))
        var lessons: [Lesson] = []

        decodedLessons.forEach()
        {
            dl in
            let newLesson = Lesson(webuntisAPI: webuntisAPI, decodedLesson: dl)
            if newLesson.durationInHours > 1
            {
                for i in newLesson.hourIndex..<newLesson.hourIndex + newLesson.durationInHours
                {
                    var subLesson = newLesson
                    subLesson.changeDurations(newHourIndex: i,newStartTime: webuntisAPI.timeGrid.timeUnits[i-1].startTime, newEndTime: webuntisAPI.timeGrid.timeUnits[i-1].endTime, newDuration: 1)
                    print(subLesson)
                    lessons.append(subLesson)
                }
            }
            else
            {
                lessons.append(newLesson)
            }
        }
        return lessons
    }

    struct DecodedLesson: Decodable
    {
        let id: Int
        let date: Date
        let startTime: Int
        let endTime: Int
        let code: String?
        let klassen: [Int]
        let teachers: [Teacher]
        let subject: Int
        let rooms: [Int]

        enum CodingKeys: String, CodingKey {
            case id, date, startTime, endTime, code, kl, te, su, ro
        }

        struct ID: Decodable
        {
            let id: Int
        }

        init(from decoder: Decoder) throws {

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"

            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decode(Int.self, forKey: .id)
            self.date = try dateFormatter.date(from: String(container.decode(Int.self, forKey: .date)))!
            self.klassen = try container.decode([ID].self, forKey: .kl).map() { $0.id }
            let teachersIds = try container.decode([ID].self, forKey: .te).map() { $0.id }
            var teachers: [Teacher] = []
            teachersIds.forEach()
            {
                id in
                teachers.append(Teacher(id: id))
            }
            self.teachers = teachers
            self.code = try container.decodeIfPresent(String.self, forKey: .code)
            let subjects = try container.decode([ID].self, forKey: .su)
            self.subject = subjects.count > 0 ? subjects[0].id : 0
            self.rooms = try container.decode([ID].self, forKey: .ro).map() { $0.id }
            self.startTime = try container.decode(Int.self, forKey: .startTime)
            self.endTime = try container.decode(Int.self, forKey: .endTime)
        }
    }
}

struct SchoolYear: Decodable
{
    let id: Int
    let name: String
    let startDate: Date
    let endDate: Date

    enum CodingKeys: String, CodingKey {
        case id, name, startDate, endDate
    }

    private init()
    {
        id = 0
        name = ""
        startDate = Date()
        endDate = Date()
    }

    static let empty = SchoolYear()

    init(from decoder: Decoder) throws {

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startDate = try dateFormatter.date(from: String(container.decode(Int.self, forKey: .startDate))) ?? Date()
        endDate = try dateFormatter.date(from: String(container.decode(Int.self, forKey: .endDate))) ?? Date()
    }
}

enum GetTypes: String
{
    case login, subjects, klassen, rooms, holidays, departments, timegridUnits, currentSchoolyear, timetable
}

enum LessonSpecification: String
{
    case ls, oh, sb, bs, ex, cancelled, irregular, holiday, excursion

    func getNameOfSpecification() -> String
    {
        switch(self)
        {
        case .ls:
            return "Lesson"
        case .oh:
            return "Office Hour"
        case .sb:
            return "Standby"
        case .bs:
            return "Break Supervision"
        case .ex:
            return "Examination"
        case .cancelled:
            return "Cancelled"
        case .irregular:
            return "Irregular"
        case .holiday:
            return "Holiday"
        case .excursion:
            return "Excursion"
        }
    }

    func getColorOfSpecify() -> (foreground: Color, background: Color)
    {
        switch(self)
        {
        case .ls:
            return (Color(hex: "0x000000"), Color(hex: "0xe1e9f1"))
        case .oh:
            return (Color(hex: "0xe6e3e1"), Color(hex: "0x250eee"))
        case .sb:
            return (Color(hex: "0x000000"), Color(hex: "0x1feee7"))
        case .bs:
            return (Color(hex: "0x000000"), Color(hex: "0xc03b6e"))
        case .ex:
            return (Color(hex: "0x000000"), Color(hex: "0xfdc400"))
        case .cancelled:
            return (Color(hex: "0x000000"), Color(hex: "0x858585"))
        case .irregular:
            return (Color(hex: "0x000000"), Color(hex: "0xa458d6"))
        case .holiday:
            return (Color(hex: "0x000000"), Color(hex: "0x439CD8"))
        case .excursion:
            return (Color(hex: "0x000000"), Color(hex: "0xd13936"))
        }
    }
}

struct LessonSpan: Decodable
{
    let name: String
    let startTime: Int
    let endTime: Int

    enum CodingKeys: String, CodingKey {
        case name, startTime, endTime
    }

    func asString() -> (String, String)
    {
        return (String(startTime / 100) + ":" + String(format: "%02d", startTime % 100), String(endTime / 100) + ":" + String(format: "%02d", endTime % 100))
    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        startTime = try container.decode(Int.self, forKey: .startTime)
        endTime = try container.decode(Int.self, forKey: .endTime)
    }
}

struct Teacher: Equatable
{
    let id: Int
    let name: String
    let longName: String

    init(id: Int)
    {
        self.id = id
        self.name = Teacher.TeachersDictionary[id]?[0] ?? "??"
        self.longName = Teacher.TeachersDictionary[id]?[1] ?? String(id)
    }

    static let TeachersDictionary: [Int: [String]] = [
        0: ["--", "Ausgetragen"],
        100: ["BO", "Bogensperger"],
        196: ["FA", "Farmer"],
        101: ["CL", "Chemloul"],
        110: ["HY", "Haynaly"],
        242: ["HB", "Heber-Körbler"],
        116: ["KW", "Kohlweg"],
        153: ["VL", "Volleritsch"],
        112: ["RC", "Reischl"],
        159: ["WR", "Wiesler"],
        123: ["PA", "Pabst"],
        266: ["LR", "Loibner"],
        184: ["VA", "Valesi"],
        200: ["PD", "Paulus"],
        259: ["OS", "Obeso"],
        149: ["TR", "Traumüller-Haynaly"],
        152: ["VK", "Völk"],
        207: ["JR", "Jerman"],
        201: ["WS", "Welser"],
        106: ["GU", "Gugerbauer"],
        143: ["SL", "Wadler"],
        120: ["MT", "Mathauer"],
        131: ["RH", "Reicht"],
        183: ["TA", "Taucher"],
        197: ["PS", "Passath"],
        156: ["WI", "Wilfling"],
        105: ["JR", "Jerman"],
        137: ["BS", "Staines"],
        160: ["WU", "Wurzinger"],
        157: ["WL", "Walzl"],
        270: ["SA", "Sammer"],
        146: ["SU", "Stückler"],
        264: ["HR", "Herischko"],
        202: ["BA", "Bauer"],
        245: ["SY", "Schöttl"]
    ]
}

