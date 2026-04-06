import 'package:flutter/material.dart';

enum SpaceRole { owner, admin, member }

enum InvitationStatus { pending, accepted, declined, expired }

class SpaceModel {
  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;

  const SpaceModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
  });

  factory SpaceModel.fromJson(Map<String, dynamic> json) {
    return SpaceModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      ownerId: (json['owner_id'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner_id': ownerId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class SpaceMemberModel {
  final String id;
  final String spaceId;
  final String userId;
  final SpaceRole role;
  final DateTime joinedAt;
  final String? displayName;
  final String? email;
  final bool isPending;

  const SpaceMemberModel({
    required this.id,
    required this.spaceId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.displayName,
    this.email,
    this.isPending = false,
  });

  factory SpaceMemberModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'];
    String? displayName;
    String? email;
    if (profile is Map) {
      displayName = profile['full_name']?.toString();
      email = profile['email']?.toString();
    }
    return SpaceMemberModel(
      id: (json['id'] ?? '').toString(),
      spaceId: (json['space_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      role: parseSpaceRole((json['role'] ?? 'member').toString()),
      joinedAt:
          DateTime.tryParse((json['joined_at'] ?? '').toString()) ??
          DateTime.now(),
      displayName: displayName,
      email: email,
      isPending: json['is_pending'] == true,
    );
  }
}

class InvitationModel {
  final String id;
  final String spaceId;
  final String invitedBy;
  final String invitedEmail;
  final String? invitedUserId;
  final InvitationStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? spaceName;
  final String? inviterName;
  final String? inviterEmail;

  const InvitationModel({
    required this.id,
    required this.spaceId,
    required this.invitedBy,
    required this.invitedEmail,
    required this.invitedUserId,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.spaceName,
    this.inviterName,
    this.inviterEmail,
  });

  factory InvitationModel.fromJson(Map<String, dynamic> json) {
    final space = json['spaces'];
    final inviter = json['inviter_profile'];
    return InvitationModel(
      id: (json['id'] ?? '').toString(),
      spaceId: (json['space_id'] ?? '').toString(),
      invitedBy: (json['invited_by'] ?? '').toString(),
      invitedEmail: (json['invited_email'] ?? '').toString(),
      invitedUserId: json['invited_user_id']?.toString(),
      status: parseInvitationStatus((json['status'] ?? 'pending').toString()),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse((json['expires_at'] ?? '').toString()) ??
          DateTime.now().add(const Duration(days: 7)),
      spaceName: space is Map ? space['name']?.toString() : null,
      inviterName: inviter is Map ? inviter['full_name']?.toString() : null,
      inviterEmail: inviter is Map ? inviter['email']?.toString() : null,
    );
  }
}

class ActivityLogModel {
  final String id;
  final String spaceId;
  final String userId;
  final String action;
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final String? userName;
  final String? userEmail;

  const ActivityLogModel({
    required this.id,
    required this.spaceId,
    required this.userId,
    required this.action,
    required this.description,
    required this.metadata,
    required this.createdAt,
    this.userName,
    this.userEmail,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'];
    return ActivityLogModel(
      id: (json['id'] ?? '').toString(),
      spaceId: (json['space_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : (json['metadata'] is Map
                ? Map<String, dynamic>.from(json['metadata'] as Map)
                : null),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      userName: profile is Map ? profile['full_name']?.toString() : null,
      userEmail: profile is Map ? profile['email']?.toString() : null,
    );
  }
}

SpaceRole parseSpaceRole(String value) {
  switch (value) {
    case 'owner':
      return SpaceRole.owner;
    case 'admin':
      return SpaceRole.admin;
    default:
      return SpaceRole.member;
  }
}

String spaceRoleValue(SpaceRole role) {
  switch (role) {
    case SpaceRole.owner:
      return 'owner';
    case SpaceRole.admin:
      return 'admin';
    case SpaceRole.member:
      return 'member';
  }
}

String spaceRoleLabel(SpaceRole role) {
  switch (role) {
    case SpaceRole.owner:
      return 'Owner';
    case SpaceRole.admin:
      return 'Admin';
    case SpaceRole.member:
      return 'Member';
  }
}

Color spaceRoleColor(SpaceRole role) {
  switch (role) {
    case SpaceRole.owner:
      return const Color(0xFFF5B700);
    case SpaceRole.admin:
      return const Color(0xFF2E90FA);
    case SpaceRole.member:
      return const Color(0xFF94A3B8);
  }
}

InvitationStatus parseInvitationStatus(String value) {
  switch (value) {
    case 'accepted':
      return InvitationStatus.accepted;
    case 'declined':
      return InvitationStatus.declined;
    case 'expired':
      return InvitationStatus.expired;
    default:
      return InvitationStatus.pending;
  }
}

String invitationStatusValue(InvitationStatus status) {
  switch (status) {
    case InvitationStatus.pending:
      return 'pending';
    case InvitationStatus.accepted:
      return 'accepted';
    case InvitationStatus.declined:
      return 'declined';
    case InvitationStatus.expired:
      return 'expired';
  }
}
