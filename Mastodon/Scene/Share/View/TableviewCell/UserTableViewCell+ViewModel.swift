//
//  UserTableViewCell+ViewModel.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-19.
//

import UIKit
import CoreDataStack
import MastodonUI
import Combine
import MastodonCore
import MastodonSDK

extension UserTableViewCell {
    final class ViewModel {
        let account: Mastodon.Entity.Account

        let followedUsers: AnyPublisher<[String], Never>
        let blockedUsers: AnyPublisher<[String], Never>
        let followRequestedUsers: AnyPublisher<[String], Never>
        
        init(account: Mastodon.Entity.Account, followedUsers: AnyPublisher<[String], Never>, blockedUsers: AnyPublisher<[String], Never>, followRequestedUsers: AnyPublisher<[String], Never>) {
            self.account = account
            self.followedUsers = followedUsers
            self.followRequestedUsers = followRequestedUsers
            self.blockedUsers =  blockedUsers
        }
    }
}

extension UserTableViewCell {

    func configure(
        me: Mastodon.Entity.Account,
        tableView: UITableView,
        account: Mastodon.Entity.Account,
        relationship: Mastodon.Entity.Relationship?,
        delegate: UserTableViewCellDelegate?
    ) {
        userView.configure(with: account, relationship: relationship, delegate: delegate)

        let isMe = account.id == me.id
        userView.updateButtonState(with: relationship, isMe: isMe)

        self.delegate = delegate
    }
}

extension UserTableViewCellDelegate where Self: ViewControllerWithDependencies & AuthContextProvider {
    func userView(_ view: UserView, didTapButtonWith state: UserView.ButtonState, for account: Mastodon.Entity.Account, me: Mastodon.Entity.Account?) {
        Task {
            await MainActor.run { view.setButtonState(.loading) }

            try await DataSourceFacade.responseToUserViewButtonAction(
                dependency: self,
                account: account,
                buttonState: state
            )

            // this is a dirty hack to give the backend enough time to process the relationship-change
            // Otherwise the relationship might still be `pending`
            if #available(iOS 16, *) {
                try await Task.sleep(for: .seconds(1))
            } else {
                try await Task.sleep(nanoseconds: .second * 1)
            }

            let relationship = try await self.context.apiService.relationship(forAccounts: [account], authenticationBox: authContext.mastodonAuthenticationBox).value.first

            let isMe: Bool
            if let me {
                isMe = account.id == me.id
            } else {
                isMe = false
            }

            await MainActor.run {
                view.viewModel.relationship = relationship
                view.updateButtonState(with: relationship, isMe: isMe)
            }
        }
    }
}
