//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import MatrixRustSDK
import Testing

@MainActor
struct TimelineItemFactoryTests {
    @Test
    func irisCardUsesRawExtensionAndDisablesTextEditing() throws {
        let userID = "@alice:iris.example"
        let factory = RoomTimelineItemFactory(userID: userID,
                                              attributedStringBuilder: AttributedStringBuilder(mentionBuilder: MentionBuilder()),
                                              stateEventStringBuilder: RoomStateEventStringBuilder(userID: userID))
        let card = try #require(IrisHTMLCard.prepare("<h2>Report</h2><table><tr><td>Ready</td></tr></table>"))
        let json = try "{\"content\":\(card.extraContentJSON())}"
        let event = EventTimelineItem(configuration: .init(latestJSON: json, isOwn: true, isEditable: true, content: EventTimelineItem.mockMessage.content))
        let proxy = EventTimelineItemProxy(item: event, uniqueID: .init("iris"))
        let item = try #require(factory.buildTimelineItem(for: proxy, isDM: false) as? TextRoomTimelineItem)
        #expect(item.content.irisHTMLCard == card)
        #expect(!item.isEditable)
    }
    
    @Test
    func callInvite() throws {
        let ownUserID = "@alice:matrix.org"
        let senderUserID = "@bob:matrix.org"
        
        let factory = RoomTimelineItemFactory(userID: ownUserID,
                                              attributedStringBuilder: AttributedStringBuilder(mentionBuilder: MentionBuilder()),
                                              stateEventStringBuilder: RoomStateEventStringBuilder(userID: ownUserID))
        
        let eventTimelineItem = EventTimelineItem.mockCallInvite(sender: senderUserID)
        
        let eventTimelineItemProxy = EventTimelineItemProxy(item: eventTimelineItem, uniqueID: .init("0"))
        
        let item = try #require(factory.buildTimelineItem(for: eventTimelineItemProxy, isDM: false) as? CallInviteRoomTimelineItem,
                                "Incorrect item type")
        
        #expect(item.isReactable == false)
        #expect(item.canBeRepliedTo == false)
        #expect(item.isEditable == false)
        #expect(item.sender == TimelineItemSender(id: senderUserID))
        #expect(item.properties.isEdited == false)
        #expect(item.properties.reactions == [])
        #expect(item.properties.deliveryStatus == nil)
    }
}
